import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/profile_avatar.dart';
import '../../core/widgets/top_bar.dart';
import '../auth/auth_controller.dart';
import '../auth/user_repository.dart';
import 'photo_service.dart';
import 'profile_data.dart';

/// SCR-17 — Edit Profil (F-07): ganti foto (kamera/galeri), ubah nama,
/// ganti password dengan verifikasi password lama, tombol Simpan.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int? _userId;
  String? _initialPhotoPath;
  String? _newPhotoPath;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = ref.read(authControllerProvider).userId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final repo = await ref.read(userRepositoryProvider.future);
      final user = await repo.byId(userId);
      if (!mounted) return;
      setState(() {
        _userId = userId;
        _initialPhotoPath = user?.photoPath;
        _newPhotoPath = user?.photoPath;
        _nameController.text = user?.name ?? '';
        _emailController.text = user?.email ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.of(context).danger500,
        content: Text(message),
      ),
    );
  }

  Future<void> _pickPhoto({required bool fromCamera}) async {
    final picker = ref.read(photoPickerProvider);
    final picked = fromCamera
        ? await picker.pickFromCamera()
        : await picker.pickFromGallery();
    if (picked == null) return;
    final saved = await ref.read(profilePhotoStoreProvider).save(picked);
    if (mounted) setState(() => _newPhotoPath = saved);
  }

  Future<void> _save() async {
    if (_saving || _userId == null) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty) {
      _showError('Nama lengkap wajib diisi.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showError('Format email tidak valid.');
      return;
    }

    final changingPassword = newPassword.isNotEmpty || confirmPassword.isNotEmpty;
    if (changingPassword) {
      if (currentPassword.isEmpty) {
        _showError('Isi password lama untuk mengganti password.');
        return;
      }
      if (newPassword.length < 8) {
        _showError('Password baru minimal 8 karakter.');
        return;
      }
      if (newPassword != confirmPassword) {
        _showError('Konfirmasi password baru tidak cocok.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final repo = await ref.read(userRepositoryProvider.future);
      await repo.updateProfile(
        id: _userId!,
        name: name,
        email: email,
        photoPath: _newPhotoPath != _initialPhotoPath ? _newPhotoPath : null,
      );
      if (changingPassword) {
        await repo.updatePassword(
          id: _userId!,
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
      }
      ref.invalidate(profileDataProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil disimpan.')),
      );
      context.pop();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Gagal menyimpan profil. Coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);

    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Edit Profil', showBack: true),
      body: _loading
          ? const Center(
              child: SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---- Ganti foto (kamera/galeri) ------------------------
                  Center(
                    child: Stack(
                      children: [
                        ProfileAvatar(
                          photoPath: _newPhotoPath,
                          name: _nameController.text,
                          radius: AppLayout.avatarLarge / 2 + 8,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.micro),
                            decoration: BoxDecoration(
                              color: p.primary500,
                              shape: BoxShape.circle,
                              border: Border.all(color: p.surface, width: 2),
                            ),
                            child: Icon(
                              Icons.edit,
                              size: 16,
                              color: p.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.grid),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        key: const ValueKey<String>('pick-camera'),
                        onPressed: () => _pickPhoto(fromCamera: true),
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('Kamera'),
                      ),
                      const SizedBox(width: AppSpacing.grid),
                      TextButton.icon(
                        key: const ValueKey<String>('pick-gallery'),
                        onPressed: () => _pickPhoto(fromCamera: false),
                        icon: const Icon(Icons.photo_library_outlined,
                            size: 18),
                        label: const Text('Galeri'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.cardGap),

                  // ---- Identitas -----------------------------------------
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nama lengkap'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: AppSpacing.cardGap),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                  ),
                  const SizedBox(height: AppSpacing.screenMargin),

                  // ---- Ganti password (opsional) -------------------------
                  Text(
                    'Ganti Password (opsional)',
                    style: AppTypography.body2.copyWith(
                      color: p.neutral500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.grid),
                  TextField(
                    controller: _currentPasswordController,
                    decoration:
                        const InputDecoration(labelText: 'Password lama'),
                    obscureText: true,
                  ),
                  const SizedBox(height: AppSpacing.cardGap),
                  TextField(
                    controller: _newPasswordController,
                    decoration:
                        const InputDecoration(labelText: 'Password baru'),
                    obscureText: true,
                  ),
                  const SizedBox(height: AppSpacing.cardGap),
                  TextField(
                    controller: _confirmPasswordController,
                    decoration:
                        const InputDecoration(labelText: 'Ulangi password baru'),
                    obscureText: true,
                  ),
                  const SizedBox(height: AppSpacing.screenMargin),

                  PrimaryButton(
                    label: 'Simpan',
                    loading: _saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
    );
  }
}
