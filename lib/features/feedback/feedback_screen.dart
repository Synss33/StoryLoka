import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/feedback_repository.dart';
import '../../core/models/feedback_item.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/storyloka_card.dart';
import '../../core/widgets/top_bar.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_store.dart';

/// SCR-10 — Saran & Kesan Mata Kuliah Pemrograman Aplikasi Mobile (F-08).
///
/// Dua kolom isian; isian terakhir tampil ulang dan dapat diedit.
/// Simpan selalu ke tabel lokal (`synced = 0`), lalu dikirim ke web service
/// `POST /feedback` — bila gagal (offline), antrean dikirim lewat `/sync`.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _kesanController = TextEditingController();
  final _saranController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _status;

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
      final repo = await ref.read(feedbackRepositoryProvider.future);
      var existing = await repo?.read(userId);

      // Data lokal masih kosong (perangkat baru) → tarik isi terakhir
      // dari web service (GET /feedback) — F-08 online.
      if (existing == null) {
        final token =
            await onlineTokenOf(ref.read(authStoreProvider));
        final response =
            await ref.read(apiClientProvider).tryGetJson('/feedback',
                token: token);
        final remote = response.body?['feedback'];
        if (remote is Map<String, dynamic>) {
          final kesan = remote['kesan'] as String?;
          final saran = remote['saran'] as String?;
          if (kesan != null || saran != null) {
            await repo?.applyServer(
              FeedbackItem(
                userId: userId,
                kesan: kesan,
                saran: saran,
                updatedAt: (remote['updated_at'] as num?)?.toInt() ?? 0,
              ),
            );
            existing = await repo?.read(userId);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _kesanController.text = existing?.kesan ?? '';
        _saranController.text = existing?.saran ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _kesanController.dispose();
    _saranController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final userId = ref.read(authControllerProvider).userId;
    if (userId == null) return;

    final kesan = _kesanController.text.trim();
    final saran = _saranController.text.trim();
    if (kesan.isEmpty && saran.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi minimal satu kolom (kesan atau saran).'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // 1) Selalu tersimpan lokal lebih dulu (F-08: tersimpan lokal).
      final repo = await ref.read(feedbackRepositoryProvider.future);
      final item = FeedbackItem(
        userId: userId,
        kesan: kesan.isEmpty ? null : kesan,
        saran: saran.isEmpty ? null : saran,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await repo?.save(item);

      // 2) Kirim ke web service (gagal = tetap antre untuk /sync).
      final token = await onlineTokenOf(ref.read(authStoreProvider));
      final sent = await ref.read(apiClientProvider).tryPostJson(
            '/feedback',
            body: item.toJson()..remove('id')..remove('user_id'),
            token: token,
          );
      if (sent) {
        final stored = await repo?.read(userId);
        if (stored?.id != null) await repo?.markSynced(<int>[stored!.id!]);
      }

      if (!mounted) return;
      setState(() {
        _status = sent
            ? 'Tersimpan lokal & terkirim.'
            : 'Tersimpan lokal — akan terkirim saat online.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_status!)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);

    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Kesan & Saran PAM'),
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
                  Text(
                    'Kesan & Saran Mata Kuliah\nPemrograman Aplikasi Mobile',
                    style: AppTypography.h3,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.cardGap),
                  StorylokaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💬 Kesan terhadap mata kuliah PAM',
                          style: AppTypography.body1,
                        ),
                        const SizedBox(height: AppSpacing.grid),
                        TextField(
                          key: const ValueKey<String>('field-kesan'),
                          controller: _kesanController,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            hintText: 'Tulis kesanmu…',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.cardGap),
                  StorylokaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💡 Saran untuk perkuliahan PAM',
                          style: AppTypography.body1,
                        ),
                        const SizedBox(height: AppSpacing.grid),
                        TextField(
                          key: const ValueKey<String>('field-saran'),
                          controller: _saranController,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            hintText: 'Tulis saranmu…',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.cardGap),
                  PrimaryButton(
                    label: 'SIMPAN / KIRIM',
                    loading: _saving,
                    onPressed: _save,
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: AppSpacing.grid),
                    Text(
                      _status!,
                      style: AppTypography.caption.copyWith(color: p.neutral500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
