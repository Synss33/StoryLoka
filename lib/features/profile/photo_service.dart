import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Pengambil foto profil dari kamera/galeri (SCR-17, F-07).
///
/// Berupa antarmuka agar pengujian (TC-10) dapat menyuntikkan pemilih
/// palsu tanpa panggilan platform kamera/galeri.
abstract class PhotoPicker {
  Future<String?> pickFromCamera();

  Future<String?> pickFromGallery();
}

/// Implementasi produksi memakai paket `image_picker`
/// (deskripsi proyek Bagian 5.4 — kamera/galeri).
class ImagePhotoPicker implements PhotoPicker {
  @override
  Future<String?> pickFromCamera() => _pick(ImageSource.camera);

  @override
  Future<String?> pickFromGallery() => _pick(ImageSource.gallery);

  Future<String?> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    return file?.path;
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => ImagePhotoPicker());

/// Menyalin foto terpilih ke direktori dokumen aplikasi agar path
/// tetap stabil (file sementara milik picker bisa dibersihkan sistem).
class ProfilePhotoStore {
  ProfilePhotoStore({this.directory});

  /// Direktori tujuan; `null` = direktori dokumen aplikasi (produksi).
  final Directory? directory;

  /// [sourcePath] berkas hasil pilih → disimpan sebagai
  /// `profile_photo.<ekstensi>` dan path-nya dikembalikan.
  Future<String> save(String sourcePath) async {
    final dir = directory ?? await getApplicationDocumentsDirectory();
    var ext = p.extension(sourcePath);
    if (ext.isEmpty) ext = '.jpg';
    final destination = p.join(dir.path, 'profile_photo$ext');
    await File(sourcePath).copy(destination);
    return destination;
  }
}

final profilePhotoStoreProvider =
    Provider<ProfilePhotoStore>((ref) => ProfilePhotoStore());
