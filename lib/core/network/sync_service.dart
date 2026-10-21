import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../features/auth/auth_store.dart';
import '../db/book_repository.dart';
import '../db/block_repository.dart';
import '../db/database_provider.dart';
import '../db/feedback_repository.dart';
import '../db/note_quote_repository.dart';
import '../db/reading_session_repository.dart';
import '../db/review_repository.dart';
import '../db/settings_repository.dart';
import '../models/app_settings.dart';
import '../models/block.dart';
import '../models/feedback_item.dart';
import '../models/note_quote.dart';
import '../models/book.dart';
import '../models/reading_session.dart';
import '../models/review.dart';
import 'api_client.dart';

/// Sinkronisasi dua arah (F-05, alur workflow §3.7):
///
/// ```text
/// perubahan lokal → dirty + updated_at → online?
///    ya   → POST /sync → server membalas snapshot → last-write-wins → tandai synced
///    tidak→ tetap antrean, dicoba lagi dengan backoff (coba saat koneksi kembali)
/// ```
///
/// Konflik diselesaikan *last-write-wins* berdasarkan `updated_at`
/// (deskripsi Bagian 5.2); tabel append-only (catatan, ulasan, blok)
/// memakai *insert-if-absent*. `settings.last_sync` mencatat waktu server
/// terakhir untuk referensi berikutnya.
class SyncService {
  SyncService({
    required this._db,
    required this._client,
    required this._store,
  });

  final Database _db;
  final ApiClient _client;
  final AuthStore _store;

  /// Backoff coba ulang (detik) selama ada antrean tapi server tak terjangkau.
  static const List<int> _backoffSeconds = [5, 15, 60, 300];

  bool _running = false;
  Timer? _retry;
  int _retryStep = 0;

  bool get isRunning => _running;

  /// Masih ada pekerjaan tertunda (buku `dirty` / feedback belum `synced`)?
  Future<bool> hasPending() async {
    final bookCount = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM books WHERE dirty = 1',
    );
    if ((bookCount.first['n'] as int) > 0) return true;
    final feedbackCount = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM feedback WHERE synced = 0',
    );
    return (feedbackCount.first['n'] as int) > 0;
  }

  /// Menjalankan satu putaran sinkronisasi. Mengembalikan `true` bila
  /// server menerima data (berhasil). Aman dipanggil berulang.
  Future<bool> syncNow() async {
    if (_running) return false;
    _running = true;
    try {
      final session = await _store.readSession();
      if (session == null) return false; // belum login → tidak ada yang dikirim

      final books = BookRepository(_db);
      final sessions = ReadingSessionRepository(_db);
      final notes = NoteQuoteRepository(_db);
      final reviews = ReviewRepository(_db);
      final blocks = BlockRepository(_db);
      final feedback = FeedbackRepository(_db);
      final settings = SettingsRepository(_db);

      final pendingBooks = await books.pendingSync(session.userId);
      final pendingFeedback = await feedback.pendingSync();
      final localSettings = await settings.read(session.userId);

      final payload = <String, Object?>{
        'since': localSettings?.lastSync ?? 0,
        'books': pendingBooks.map((b) => b.toJson()).toList(),
        'sessions': (await sessions.listAll()).map((s) => s.toJson()).toList(),
        'notes': (await notes.listAll()).map((n) => n.toJson()).toList(),
        'reviews': (await reviews.listAll()).map((r) => r.toJson()).toList(),
        'blocks':
            (await blocks.listByUser(session.userId)).map((b) => b.toJson()).toList(),
        'feedback': pendingFeedback.map((f) => f.toJson()).toList(),
        'settings': localSettings?.toJson(),
      };

      final response = await _client.postJson(
        '/sync',
        body: payload,
        token: await onlineTokenOf(_store),
      );
      if (response.offline || !response.ok) return false;

      await _applyResponse(
        response.body ?? const <String, dynamic>{},
        userId: session.userId,
        pendingBookIds:
            pendingBooks.map((b) => b.id).whereType<int>().toList(),
        pendingFeedbackIds:
            pendingFeedback.map((f) => f.id).whereType<int>().toList(),
      );

      // Perubahan baru yang muncul selama sync berjalan → jalankan lagi.
      if (await hasPending()) {
        _retryStep = 0;
        kick();
      } else {
        _retry?.cancel();
        _retry = null;
        _retryStep = 0;
      }
      return true;
    } finally {
      _running = false;
    }
  }

  /// Memulai sinkronisasi segera bila ada antrean; bila gagal (offline),
  /// menjadwalkan percobaan ulang dengan backoff — antrean tidak hilang
  /// sampai server menerima data (workflow §3.7).
  void kick() {
    if (_running || _retry != null) return;
    unawaited(_attempt());
  }

  Future<void> _attempt() async {
    var ok = false;
    try {
      ok = await syncNow();
    } catch (e) {
      // Kegagalan tak terduga (DB tutup, dsb.) diperlakukan seperti offline.
      debugPrint('[sync] percobaan gagal: $e');
    }
    if (ok) {
      _retryStep = 0;
      return;
    }
    var pending = false;
    try {
      pending = await hasPending();
    } catch (_) {
      // DB tidak terbaca → tetap coba lagi nanti.
      pending = true;
    }
    if (!pending) {
      _retryStep = 0;
      return;
    }
    final delay = _backoffSeconds[
        _retryStep < _backoffSeconds.length ? _retryStep : _backoffSeconds.length - 1];
    _retryStep++;
    _retry = Timer(Duration(seconds: delay), () {
      _retry = null;
      kick();
    });
  }

  /// Menerapkan balasan server: terapkan LWW per baris, tandai antrean
  /// lokal selesai, dan catat `last_sync`.
  Future<void> _applyResponse(
    Map<String, dynamic> body, {
    required int userId,
    required List<int> pendingBookIds,
    required List<int> pendingFeedbackIds,
  }) async {
    final books = BookRepository(_db);
    final sessions = ReadingSessionRepository(_db);
    final notes = NoteQuoteRepository(_db);
    final reviews = ReviewRepository(_db);
    final blocks = BlockRepository(_db);
    final feedback = FeedbackRepository(_db);
    final settings = SettingsRepository(_db);

    for (final raw in _rows(body['books'])) {
      await books.applyServer(Book.fromRow(raw));
    }
    for (final raw in _rows(body['sessions'])) {
      await sessions.applyServer(ReadingSession.fromRow(raw));
    }
    await notes.applySnapshot(
      _rows(body['notes']).map(NoteQuote.fromRow).toList(),
    );
    await reviews.applySnapshot(
      _rows(body['reviews']).map(Review.fromRow).toList(),
    );
    await blocks.applySnapshot(
      _rows(body['blocks']).map(Block.fromRow).toList(),
    );
    for (final raw in _rows(body['feedback'])) {
      await feedback.applyServer(FeedbackItem.fromRow(raw));
    }

    final serverSettings = body['settings'];
    if (serverSettings is Map) {
      final incoming =
          AppSettings.fromRow(Map<String, Object?>.from(serverSettings));
      final local = await settings.read(userId);
      if (local == null || incoming.updatedAt > local.updatedAt) {
        await settings.applyServer(incoming);
      }
    }

    await books.markSynced(pendingBookIds);
    await feedback.markSynced(pendingFeedbackIds);

    final serverTime = body['serverTime'];
    if (serverTime is int) {
      await settings.setLastSync(userId, serverTime);
    }
  }

  /// Mengubah elemen array JSON menjadi row map (key = nama kolom).
  static List<Map<String, Object?>> _rows(Object? value) {
    if (value is! List) return const <Map<String, Object?>>[];
    return value
        .whereType<Map>()
        .map((m) => Map<String, Object?>.from(m))
        .toList();
  }

  /// Membatalkan percobaan ulang yang terjadwal (dipakai saat logout/DB tutup).
  void dispose() {
    _retry?.cancel();
    _retry = null;
  }
}

/// Layanan sinkronisasi dari database aktif (null bila DB tidak terbuka).
final syncServiceProvider = FutureProvider<SyncService?>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  if (db == null) return null;
  final service = SyncService(
    db: db,
    client: ref.watch(apiClientProvider),
    store: ref.watch(authStoreProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
