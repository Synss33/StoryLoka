import 'package:sqflite_sqlcipher/sqflite.dart';

/// Skema database lokal Storyloka v1 — dokumen deskripsi proyek Bagian 5.2.
///
/// Konvensi kolom (keputusan dicatat di `docs/keputusan.md`):
/// * Waktu disimpan sebagai INTEGER **epoch millisecond (UTC)** agar mudah
///   dibandingkan untuk aturan *last-write-wins* dan hitung durasi sesi.
/// * Boolean disimpan sebagai INTEGER 0/1.
/// * `dirty` (1 = belum tersinkron) dan `deleted` (1 = soft delete)
///   disediakan untuk antrean sinkronisasi (modul WF-03).
abstract final class AppDatabase {
  /// Versi skema. Setiap perubahan wajib menaikkan nomor + menulis onUpgrade.
  ///
  /// * v1 = pembuatan awal (WF-01).
  /// * v2 = `settings.updated_at` agar konflik pengaturan bisa diselesaikan
  ///   dengan *last-write-wins* sinkronisasi (WF-03).
  /// * v3 = `settings.streak_notify` (toggle notifikasi target & streak
  ///   di SCR-09, WF-04; penjadwalannya WF-06).
  /// * v4 = tabel `ai_cache` (cache ringkasan AI SCR-06, WF-07).
  static const int version = 4;

  /// Nama berkas database terenkripsi.
  static const String fileName = 'storyloka.db';

  /// Dijalankan pertama kali saat membuka database.
  static Future<void> onConfigure(Database db) async {
    // Agar `ON DELETE CASCADE` pada foreign key berlaku.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Membuat seluruh tabel saat database belum ada (migrasi versi 1).
  static Future<void> onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE users (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT    NOT NULL,
        email         TEXT    NOT NULL UNIQUE,
        password_hash TEXT    NOT NULL,
        salt          TEXT    NOT NULL,
        kdf_params    TEXT    NOT NULL,
        photo_path    TEXT,
        created_at    INTEGER NOT NULL,
        updated_at    INTEGER NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE books (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     INTEGER NOT NULL,
        title       TEXT    NOT NULL,
        author      TEXT    NOT NULL,
        publisher   TEXT,
        year        INTEGER,
        isbn        TEXT,
        genre       TEXT,
        pages       INTEGER,
        cover       TEXT,
        synopsis    TEXT,
        status      TEXT    NOT NULL DEFAULT 'unread'
                    CHECK (status IN ('wishlist','unread','reading','completed')),
        rating      REAL,
        price       REAL,
        started_at  INTEGER,
        finished_at INTEGER,
        updated_at  INTEGER NOT NULL,
        deleted     INTEGER NOT NULL DEFAULT 0,
        dirty       INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
    batch.execute('CREATE INDEX idx_books_user_status ON books (user_id, status)');
    batch.execute('CREATE INDEX idx_books_updated ON books (updated_at)');

    // Sesi membaca: durasi dihitung dari timestamp, bukan penghitung per detik.
    batch.execute('''
      CREATE TABLE reading_sessions (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id     INTEGER NOT NULL,
        start_ts    INTEGER NOT NULL,
        duration_sec INTEGER NOT NULL,
        last_page   INTEGER,
        note        TEXT,
        updated_at  INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');
    batch.execute('CREATE INDEX idx_sessions_book ON reading_sessions (book_id)');

    batch.execute('''
      CREATE TABLE notes_quotes (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id    INTEGER NOT NULL,
        type       TEXT    NOT NULL CHECK (type IN ('note','quote')),
        content    TEXT    NOT NULL,
        page       INTEGER,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE reviews (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id    INTEGER NOT NULL,
        rating     REAL    NOT NULL,
        text       TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    // Blockchain lokal: hash chain SHA-256 "Proof of Reading" (Bagian 5.7).
    // `idx` adalah nomor blok per pengguna → PRIMARY KEY gabungan (user_id, idx).
    batch.execute('''
      CREATE TABLE blocks (
        idx           INTEGER NOT NULL,
        user_id       INTEGER NOT NULL,
        timestamp     INTEGER NOT NULL,
        book_id       INTEGER NOT NULL,
        review_hash   TEXT    NOT NULL,
        finished_date INTEGER NOT NULL,
        previous_hash TEXT    NOT NULL,
        hash          TEXT    NOT NULL,
        PRIMARY KEY (user_id, idx),
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE feedback (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    INTEGER NOT NULL,
        kesan      TEXT,
        saran      TEXT,
        updated_at INTEGER NOT NULL,
        synced     INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE settings (
        user_id          INTEGER PRIMARY KEY,
        biometric_enabled INTEGER NOT NULL DEFAULT 0,
        reminder_on       INTEGER NOT NULL DEFAULT 1,
        reminder_time     TEXT    NOT NULL DEFAULT '20:00',
        theme_mode        TEXT    NOT NULL DEFAULT 'auto'
                            CHECK (theme_mode IN ('auto','light','dark')),
        streak_notify     INTEGER NOT NULL DEFAULT 1,
        monthly_target    INTEGER NOT NULL DEFAULT 5,
        last_sync         INTEGER,
        updated_at        INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE game_scores (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id  INTEGER NOT NULL,
        score    INTEGER NOT NULL,
        coins    INTEGER NOT NULL DEFAULT 0,
        played_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE notifications (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    INTEGER NOT NULL,
        type       TEXT    NOT NULL,
        title      TEXT    NOT NULL,
        body       TEXT,
        ref        TEXT,
        read       INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Cache kurs untuk konversi mata uang saat offline (Bagian 5.12).
    batch.execute('''
      CREATE TABLE rate_cache (
        currency    TEXT PRIMARY KEY,
        rate_to_idr REAL NOT NULL,
        fetched_at  INTEGER NOT NULL
      )
    ''');

    // Cache ringkasan AI per buku (Bagian 5.6 — "hasil ringkasan
    // di-cache lokal"); `key` mis. `summary:<bookId>` (WF-07).
    batch.execute('''
      CREATE TABLE ai_cache (
        key        TEXT PRIMARY KEY,
        user_id    INTEGER NOT NULL,
        content    TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await batch.commit(noResult: true);
  }

  /// Titik masuk migrasi skema. Versi 1 = pembuatan; nomor berikutnya
  /// ditambahkan bersama modul yang mengubah skema (WF-03 s.d. WF-09).
  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // WF-03: kolom waktu perubahan pengaturan untuk aturan LWW.
      await db.execute(
        'ALTER TABLE settings ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      // WF-04: toggle notifikasi target & streak di SCR-09.
      await db.execute(
        'ALTER TABLE settings ADD COLUMN streak_notify INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (oldVersion < 4) {
      // WF-07: cache ringkasan AI (Bagian 5.6) agar tampil saat offline.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ai_cache (
          key        TEXT PRIMARY KEY,
          user_id    INTEGER NOT NULL,
          content    TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');
    }
  }
}
