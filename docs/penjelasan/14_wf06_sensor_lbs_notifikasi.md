# WF-06 — Sensor (Shake & Auto-Theme), LBS, Notifikasi

> **Fitur:** F-15 (minimal 2 sensor), F-16 (LBS), F-14 (notifikasi mobile) · **Layar:** SCR-04 (segmen Peta), SCR-14, SCR-09 (pengingat/tema), SCR-02 (lonceng, modal shake) · **Alur:** workflow §3.6 & §3.8 · **Test:** TC-19…TC-23 (`shake_test`, `auto_theme_test`, `lbs_test`, `notification_test`)

## 1. Sensor 1 — Auto-Theme dari sensor cahaya (F-15)

**`core/sensors/auto_theme.dart:9`** — *"lux **< 15** selama ≥ 2 dtk → Dark Mode; lux **> 40** selama ≥ 2 dtk → Light Mode (**histeresis** — zona 15…40 diabaikan agar tidak berkedip); hanya aktif bila tema = **Otomatis**; mode manual mengabaikan sensor; iOS tidak punya sensor cahaya → stream kosong, tema tetap mengikuti sistem."*

- `:53` `reset()` dipanggil saat pengguna memilih mode manual.
- `luxStreamProvider` (`sensor_streams.dart:31`) — hanya Android; bila tak tersedia/channel error *"stream tetap diam tanpa menggagalkan provider"*.
- **Integrasi di `app/app.dart:33`** — `ref.listen(luxProvider)` → `autoThemeProvider.feed(lux)`; `:41` pindah mode manual → `reset()`.
- Mode tema enum: `app/theme_mode_provider.dart:6` (`auto`/`light`/`dark` — persist ke `settings.theme_mode`, WF-04).

## 2. Sensor 2 — Shake to Discover (F-15)

**`core/sensors/shake_detector.dart:19`** — *"magnitudo > 12 m/s², **2 guncangan dalam 600 ms**, lalu jeda (debounce) 1,5 dtk sebelum boleh memicu lagi. Logika murni tanpa dependensi platform — sensor asli dipasok lewat stream, pengujian memberi sampel buatan."*

| File | Komentar penting |
|---|---|
| `sensor_streams.dart:9` | stream *user accelerometer* (tanpa gravitasi) Android/iOS; platform lain stream kosong — *"tidak pernah memanggil channel platform"* |
| `shake_detector.dart:3` | magnitudo = √(x²+y²+z²); `at` memakai **timestamp sampel platform** (bukan `DateTime.now()`) → deteksi deterministik di test; `:44` diam/berjalan tidak pernah mengubah puncak (TC-20) |
| `shake_discover.dart:18` | nilai provider menaik (1, 2, 3…) tiap shake — `ref.listen` memakai perubahan nilai, bukan status async; `:33` getar → provider terpisah agar TC-19 bisa menyuntik penghitung |
| `shake_discover.dart:39` | *"Dibungkus di luar SCR-02 (`location: '/'`) dan SCR-04. Shake hanya diproses bila: layar sesuai [location] (bukan sesi baca/kuis), pengguna tidak sedang mengetik, modal belum terbuka. Efek: haptic → modal 1 buku acak dari Wishlist (kosong → rekomendasi AI)."* |

## 3. LBS — Peta toko buku/perpustakaan (F-16)

**`features/explore/peta_panel.dart:16`** — *"peta OSM + marker radius 3 km. State yang wajib: izin ditolak (kartu ajakan + **Buka Pengaturan**), GPS mati, memuat, offline/error, dan siap."*

- `core/location/location_service.dart:5` — abstraksi Geolocator: `isServiceEnabled`, `requestPermission`, `openAppSettings`, `openLocationSettings`; `:51` provider bisa di-override tiruan (**TC-22**).
- `core/network/book_place_service.dart:8` — toko buku & perpustakaan radius 3 km; `:80` Overpass API (OSM) tanpa key — *"kegagalan/melewati timeout dilempar agar layar menampilkan state offline (SCR-13)"*; `:27` jarak **Haversine dihitung lokal** (aman di test); `:33` buka/tutup dari `opening_hours`.
- `peta_panel.dart:120` tombol **Rute** → peta eksternal; `:379` format jarak ramah (800 m / 1,5 km).

## 4. Notifikasi (F-14, workflow §3.8)

**`core/notifications/notification_coordinator.dart:15`** — *"pengingat harian → `scheduleDaily` (timezone-aware); event target/streak/sertifikat → notifikasi satu kali + tabel `notifications`; ketuk notifikasi → tandai terbaca + buka layar terkait (SCR-06/15/14); saat sesi valid → rekam pengingat yang sudah lewat hari ini agar riwayat SCR-14 tetap lengkap."*

| File | Komentar penting |
|---|---|
| `notification_service.dart:27` | *"Layanan notifikasi yang dapat disuntikkan — pengujian TC-23 menyuntikkan tiruan yang merekam pemanggilan"* (K-32); `:54` implementasi `flutter_local_notifications` — semua panggilan platform try/catch dan hanya Android/iOS; `:197` zona waktu fallback `Asia/Jakarta` |
| `notification_coordinator.dart:81` | `applyReminder()` — seam yang sama dipakai SCR-09 & pengujian TC-23; `:110` `emitEvent(type, route, dedupePerDay)` — sertifikat `dedupePerDay: false` (K-45); `:206` callback ketuk: format payload `type\|userId\|rute` |
| `notification_coordinator.dart` (provider) | `:249` dibaca sinkron (`AsyncValue.value`) — bukan `await provider.future` (**K-35**, alasan test menggantung) |
| `core/db/notification_repository.dart:7` | riwayat SCR-14; `:53` tandai terbaca per tipe; `:62` dedupe "sudah ada hari ini?" |
| `features/notifications/notifications_screen.dart:15` | SCR-14: daftar + **Tandai Semua Dibaca**; ketuk → buka layar terkait; `:172` waktu ramah |
| `notifications_data.dart:18` | jumlah belum dibaca → titik merah lonceng SCR-02 |

**Pemicu event:** sesi selesai → target/streak (`notification_coordinator.dart:152`, menghormati toggle SCR-09); buku selesai → sertifikat (WF-08, K-45); pengingat harian → `scheduleDaily`.

## 5. API & platform yang dipakai

- Overpass API (`POST https://overpass-api.de/api/interpreter`) — `book_place_service.dart:87`, tanpa key.
- Izin platform: `POST_NOTIFICATIONS` (Android 13+), lokasi runtime — **K-34** (termasuk `coreLibraryDesugaring` wajib untuk `flutter_local_notifications`).
- Tidak ada endpoint backend di modul ini.

## 6. Test & keputusan

- **TC-19/20** `shake_test` (modal + haptic; diam/berjalan tidak salah picu) · **TC-21** `auto_theme_test` (histeresis ≥ 2 dtk + mode manual abaikan sensor) · **TC-22** `lbs_test` (izin ditolak → kartu ajakan + Buka Pengaturan; GPS mati) · **TC-23** `notification_test` (setelan → jadwal → fires → ketuk → riwayat; lulus 3× berturut-turut).
- Keputusan: **K-32** (abstraksi notifikasi + payload), **K-33** (OSM + Overpass $0), **K-34** (izin & desugaring + ambang shake/lux), **K-35** (baca sinkron provider).
