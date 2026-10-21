import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database_provider.dart';
import '../../core/db/settings_repository.dart';
import '../../core/network/api_client.dart';
import 'auth_store.dart';
import 'biometric_service.dart';
import 'demo_seed.dart';
import 'session_service.dart';
import 'user_repository.dart';

/// State autentikasi (WF-02).
class AuthState {
  const AuthState({
    this.busy = false,
    this.error,
    this.userId,
    this.failedAttempts = 0,
    this.biometricFailures = 0,
  });

  /// Sedang memproses hash/verifikasi (tombol dinonaktifkan + spinner).
  final bool busy;

  /// Pesan galat umum untuk form login/register.
  final String? error;

  /// Pengguna aktif setelah login/registrasi/validasi sesi.
  final int? userId;

  /// Jumlah login gagal (dicatat, ditampilkan kecil di form — workflow §3.2).
  final int failedAttempts;

  /// Jumlah biometrik gagal sejak sesi dibuka (3× → form password, TC-07).
  final int biometricFailures;

  AuthState copyWith({
    bool? busy,
    String? error,
    int? userId,
    int? failedAttempts,
    int? biometricFailures,
  }) =>
      AuthState(
        busy: busy ?? this.busy,
        error: error,
        userId: userId ?? this.userId,
        failedAttempts: failedAttempts ?? this.failedAttempts,
        biometricFailures: biometricFailures ?? this.biometricFailures,
      );
}

/// Pengendali register / login / logout / biometrik
/// (alur sistem workflow Bagian 3.1–3.2, deskripsi Bagian 5.1).
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  /// Registrasi: validasi → salt + hash → simpan lokal → buat sesi →
  /// kirim ke server bila online (gagal server tidak membatalkan registrasi).
  /// Mengembalikan `null` bila berhasil, atau pesan galat untuk form.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String confirm,
  }) async {
    if (state.busy) return null;
    state = state.copyWith(busy: true);

    try {
      if (name.trim().isEmpty) {
        return _fail('Nama lengkap wajib diisi.');
      }
      if (!_isEmail(email)) {
        return _fail('Format email tidak valid.');
      }
      if (password.length < 8) {
        return _fail('Password minimal 8 karakter.');
      }
      if (password != confirm) {
        return _fail('Konfirmasi password tidak cocok.');
      }

      final repo = await ref.read(userRepositoryProvider.future);
      final user = await repo.register(
        name: name,
        email: email,
        password: password,
      );
      await ref.read(sessionServiceProvider).start(user.id);

      // Sinkron ke server saat online — hasil tidak menentukan keberhasilan;
      // token balasan disimpan agar endpoint butuh-otorisasi diterima.
      unawaited(
        _serverAuth(
          path: '/auth/register',
          body: <String, Object?>{
            'name': user.name,
            'email': user.email,
            'password': password,
          },
        ),
      );

      state = AuthState(userId: user.id);
      return null;
    } on AuthException catch (e) {
      return _fail(e.message);
    } catch (_) {
      return _fail('Registrasi gagal. Coba lagi.');
    }
  }

  /// Login: verifikasi hash → buat sesi. Pesan galat selalu umum
  /// "Email atau password salah" (TC-03).
  Future<String?> login({
    required String identifier,
    required String password,
  }) async {
    if (state.busy) return null;
    state = state.copyWith(busy: true);

    try {
      if (identifier.trim().isEmpty || password.isEmpty) {
        return _fail('Email/username dan password wajib diisi.');
      }

      final repo = await ref.read(userRepositoryProvider.future);
      final user = await repo.findByEmailOrName(identifier);
      if (user == null || !await repo.verifyPassword(user, password)) {
        final attempts = state.failedAttempts + 1;
        state = state.copyWith(failedAttempts: attempts);
        return _fail('Email atau password salah.');
      }

      await ref.read(sessionServiceProvider).start(user.id);
      unawaited(
        _serverAuth(
          path: '/auth/login',
          body: <String, Object?>{'email': user.email, 'password': password},
        ),
      );

      state = AuthState(userId: user.id);
      return null;
    } on AuthException catch (e) {
      return _fail(e.message);
    } catch (_) {
      return _fail('Login gagal. Coba lagi.');
    }
  }

  /// Logout (F-09): hapus token sesi dan bersihkan state memori →
  /// kembali ke SCR-01. Koneksi DB ditutup oleh splash saat menemukan
  /// sesi sudah tidak ada (splash_screen.dart); data buku lokal tetap
  /// tersimpan (terenkripsi).
  Future<void> logout() async {
    if (state.busy) return;
    state = state.copyWith(busy: true);
    try {
      final session = await ref.read(sessionServiceProvider).rawSession();
      await ref.read(sessionServiceProvider).end();
      // Cabut sesi di server juga (bila online) — tidak mengubah hasil lokal.
      final serverToken = await ref.read(authStoreProvider).readServerToken();
      await ref.read(authStoreProvider).clearServerToken();
      final token = serverToken ?? session?.token;
      if (token != null) {
        unawaitedServer(path: '/auth/logout', token: token);
      }
    } finally {
      state = const AuthState();
    }
  }

  /// Masuk sebagai akun demo berisi data contoh (khusus build `DEMO_MODE`).
  /// Membuat + menyemai data bila belum ada, lalu membuka sesi lokal.
  Future<String?> loginDemo() async {
    if (state.busy) return null;
    state = state.copyWith(busy: true);
    try {
      final db = await ref.read(databaseProvider.future);
      if (db == null) {
        return _fail('Database tidak tersedia di perangkat ini.');
      }
      final userId = await DemoSeeder(db).ensure();
      await ref.read(sessionServiceProvider).start(userId);

      // Salin akun demo ke server bila online (best-effort, seperti register).
      unawaited(
        _serverAuth(
          path: '/auth/register',
          body: <String, Object?>{
            'name': DemoSeeder.name,
            'email': DemoSeeder.email,
            'password': DemoSeeder.password,
          },
        ),
      );

      state = AuthState(userId: userId);
      return null;
    } catch (_) {
      return _fail('Gagal menyiapkan akun demo. Coba lagi.');
    }
  }

  /// Mengadopsi sesi valid yang ditemukan saat splash (auto-login).
  void adoptSession(int userId) {
    state = state.copyWith(userId: userId, error: null);
  }

  /// Menyalakan/mematikan biometrik; saat menyalankan wajib verifikasi dulu
  /// (deskripsi Bagian 5.1).
  Future<String?> setBiometricEnabled(bool enabled) async {
    final userId = state.userId;
    if (userId == null) return 'Tidak ada sesi aktif.';

    if (enabled) {
      final ok = await ref
          .read(biometricServiceProvider)
          .authenticate(reason: 'Aktifkan login biometrik');
      if (!ok) return 'Verifikasi gagal — biometrik tidak diaktifkan.';
    }

    final settings = await ref.read(settingsRepositoryProvider.future);
    await settings?.setBiometricEnabled(userId, enabled);
    return null;
  }

  /// Apakah biometrik perlu diminta saat aplikasi dibuka (TC-06).
  Future<bool> shouldUseBiometric(int userId) async {
    final enabled = await _isBiometricEnabled(userId);
    if (!enabled) return false;
    return ref.read(biometricServiceProvider).isSupported();
  }

  Future<bool> _isBiometricEnabled(int userId) async {
    final settings = await ref.read(settingsRepositoryProvider.future);
    // Sumber kebenaran = tabel `settings` (deskripsi Bagian 5.1).
    if (settings == null) return false;
    return settings.isBiometricEnabled(userId);
  }

  Future<bool> promptBiometric() =>
      ref.read(biometricServiceProvider).authenticate();

  void noteBiometricFailure() => state =
      state.copyWith(biometricFailures: state.biometricFailures + 1);

  void resetBiometricFailures() =>
      state = state.copyWith(biometricFailures: 0);

  /// Menampilkan pesan umum di form (mis. hasil biometrik dari splash).
  void copyWithMessage(String message) =>
      state = state.copyWith(busy: false, error: message);

  String _fail(String message) {
    state = state.copyWith(busy: false, error: message);
    return message;
  }

  static bool _isEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

  /// Panggilan server tanpa mengubah alur lokal (offline tetap berhasil).
  void unawaitedServer({
    required String path,
    Map<String, Object?> body = const <String, Object?>{},
    String? token,
  }) {
    ref.read(apiClientProvider).tryPostJson(path, body: body, token: token);
  }

  /// Auth server fire-and-forget (register/login): memuat token sesi dari
  /// balasan `2xx` lalu menyimpannya — endpoint butuh-otorisasi (`/ai`,
  /// `/rates`, `/feedback`, `/sync`) memakai token ini (bukan token lokal).
  ///
  /// Register saat akun sudah ada di server (409 / tanpa token) otomatis
  /// dicoba ulang sebagai `/auth/login` agar token tetap diperoleh.
  Future<void> _serverAuth({
    required String path,
    Map<String, Object?> body = const <String, Object?>{},
  }) async {
    final client = ref.read(apiClientProvider);
    var response = await client.postJson(path, body: body);
    Object? token = response.body?['token'];
    if (path == '/auth/register' && (token is! String || token.isEmpty)) {
      response = await client.postJson(
        '/auth/login',
        body: <String, Object?>{
          'email': body['email'],
          if (body['password'] != null) 'password': body['password'],
        },
      );
      token = response.body?['token'];
    }
    if (response.ok && token is String && token.isNotEmpty) {
      await ref.read(authStoreProvider).writeServerToken(token);
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
