import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyloka/app/app.dart';
import 'package:storyloka/app/router.dart';

/// Smoke test fondasi WF-01: splash → Beranda, bottom nav 5 slot,
/// dan dialog konfirmasi Logout (bukan layar).
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    // Router dibuat sekali untuk seluruh aplikasi, jadi tiap tes direset
    // ke splash agar tidak mewarisi lokasi rute tes sebelumnya.
    appRouter.go('/splash');
    await tester.pumpWidget(const ProviderScope(child: StorylokaApp()));
    await tester.pump(); // memulai timer splash
    expect(find.text('Storyloka'), findsOneWidget);
    // Lewati splash 1,5 detik menuju Beranda.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
  }

  testWidgets('splash berpindah ke Beranda dan bottom nav 5 slot tampil',
      (tester) async {
    await pumpApp(tester);

    expect(find.text('Halo, Pembaca'), findsOneWidget);
    for (final label in <String>[
      'Beranda',
      'Explore',
      'Profil',
      'Kesan',
      'Logout',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'slot "$label"');
    }
  });

  testWidgets('slot Logout membuka dialog konfirmasi, bukan layar baru',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Keluar dari Storyloka?'), findsOneWidget);
    expect(find.text('Sesi akan diakhiri.'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);

    // Tutup dialog lewat Batal.
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari Storyloka?'), findsNothing);
    expect(find.text('Halo, Pembaca'), findsOneWidget);
  });

  testWidgets('berpindah tab Explore/Profil/Kesan menampilkan layarnya',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('Jelajahi Fitur Tambahan'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Profil Pengguna'), findsOneWidget);

    await tester.tap(find.text('Kesan'));
    await tester.pumpAndSettle();
    expect(find.text('Kesan & Saran Mata Kuliah PAM'), findsOneWidget);
  });

  testWidgets('layar fokus menyembunyikan bottom nav (Bagian 3.3)',
      (tester) async {
    await pumpApp(tester);

    // SCR-08 Pencarian = layar fokus: tanpa bottom nav.
    appRouter.go('/search');
    await tester.pumpAndSettle();

    expect(find.text('Pencarian'), findsOneWidget);
    expect(find.text('Beranda'), findsNothing);
    expect(find.text('Logout'), findsNothing);
  });
}
