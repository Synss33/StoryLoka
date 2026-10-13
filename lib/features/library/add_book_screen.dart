import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/db/book_repository.dart';
import '../../core/models/book.dart';
import '../../core/network/book_search_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/book_status.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/book_cover.dart';
import '../../core/widgets/top_bar.dart';
import '../auth/auth_controller.dart';
import '../home/home_data.dart';
import '../profile/photo_service.dart';
import 'library_data.dart';

/// SCR-07 — Tambah / Edit Buku (F-10, F-20 · WF-05).
///
/// Form validasi: judul* & halaman* wajib (halaman ≥ 1); sumber manual
/// atau hasil pencarian online (dikirim lewat [prefill] — TC-13);
/// sampul dari kamera/galeri (reuse PhotoPicker SCR-17).
class AddBookScreen extends ConsumerStatefulWidget {
  const AddBookScreen({super.key, this.bookId, this.prefill});

  /// ID buku untuk mode edit (rute `/book/edit?id=…`).
  final int? bookId;

  /// Isian otomatis dari hasil pencarian online (SCR-08 → "Pilih").
  final OnlineBookResult? prefill;

  @override
  ConsumerState<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends ConsumerState<AddBookScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController();
  late final TextEditingController _author = TextEditingController();
  late final TextEditingController _publisher = TextEditingController();
  late final TextEditingController _year = TextEditingController();
  late final TextEditingController _isbn = TextEditingController();
  late final TextEditingController _genre = TextEditingController();
  late final TextEditingController _pages = TextEditingController();
  late final TextEditingController _price = TextEditingController();
  late final TextEditingController _coverUrl = TextEditingController();

  BookStatus _status = BookStatus.unread;
  String? _coverPath;
  bool _saving = false;
  String? _error;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // Isi form dari mode edit / hasil pencarian online (TC-13).
    final prefill = widget.prefill;
    if (prefill != null) {
      _title.text = prefill.title;
      _author.text = prefill.author;
      _publisher.text = prefill.publisher ?? '';
      _year.text = prefill.year?.toString() ?? '';
      _isbn.text = prefill.isbn ?? '';
      _genre.text = prefill.genre ?? '';
      _pages.text = prefill.pages?.toString() ?? '';
      _coverUrl.text = prefill.cover ?? '';
    }
    // Mode edit: muat data buku yang ada (provider menunggu DB terbuka).
    if (widget.bookId != null) _loadExisting();
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _publisher.dispose();
    _year.dispose();
    _isbn.dispose();
    _genre.dispose();
    _pages.dispose();
    _price.dispose();
    _coverUrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    if (_loaded || widget.bookId == null) return;
    final repo = await ref.read(bookRepositoryProvider.future);
    final book = await repo?.get(widget.bookId!);
    if (book == null || !mounted) return;
    _title.text = book.title;
    _author.text = book.author;
    _publisher.text = book.publisher ?? '';
    _year.text = book.year?.toString() ?? '';
    _isbn.text = book.isbn ?? '';
    _genre.text = book.genre ?? '';
    _pages.text = book.pages?.toString() ?? '';
    _price.text = book.price?.toString() ?? '';
    _coverUrl.text = (book.cover != null &&
            (book.cover!.startsWith('http')))
        ? book.cover!
        : '';
    _coverPath = (book.cover != null && !book.cover!.startsWith('http'))
        ? book.cover
        : null;
    _status = BookStatus.fromCode(book.status);
    setState(() => _loaded = true);
  }

  Future<void> _pickCover(ImageSource source) async {
    final picker = ref.read(photoPickerProvider);
    final path = source == ImageSource.camera
        ? await picker.pickFromCamera()
        : await picker.pickFromGallery();
    if (path != null && mounted) {
      setState(() {
        _coverPath = path;
        _coverUrl.clear();
      });
    }
  }

  /// Simpan: validasi → insert/update → tandai dirty → kembali (TC-12).
  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final userId = ref.read(authControllerProvider).userId;
    final repo = await ref.read(bookRepositoryProvider.future);
    if (userId == null || repo == null) {
      setState(() => _error = 'Sesi tidak ditemukan. Silakan masuk lagi.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final pages = int.parse(_pages.text.trim());
      final cover = _coverPath ?? (_coverUrl.text.trim().isEmpty
          ? null
          : _coverUrl.text.trim());

      if (widget.bookId != null) {
        final existing = await repo.get(widget.bookId!);
        if (existing == null) throw StateError('Buku tidak ditemukan.');
        final now = DateTime.now().millisecondsSinceEpoch;
        await repo.update(
          existing.copyWith(
            title: _title.text.trim(),
            author: _author.text.trim(),
            publisher: _publisherOrNull(),
            year: _intOrNull(_year.text),
            isbn: _textOrNull(_isbn.text),
            genre: _textOrNull(_genre.text),
            pages: pages,
            cover: cover,
            price: _doubleOrNull(_price.text),
            status: _status.code,
            updatedAt: now,
          ),
        );
      } else {
        final now = DateTime.now().millisecondsSinceEpoch;
        await repo.insert(
          Book(
            userId: userId,
            title: _title.text.trim(),
            author: _author.text.trim(),
            publisher: _publisherOrNull(),
            year: _intOrNull(_year.text),
            isbn: _textOrNull(_isbn.text),
            genre: _textOrNull(_genre.text),
            pages: pages,
            cover: cover,
            status: _status.code,
            price: _doubleOrNull(_price.text),
            updatedAt: now,
          ),
        );
      }

      if (!mounted) return;
      // Segarkan daftar library & beranda.
      ref.invalidate(libraryBooksProvider);
      ref.invalidate(homeDataProvider);
      context.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Gagal menyimpan buku. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _publisherOrNull() {
    final v = _publisher.text.trim();
    return v.isEmpty ? null : v;
  }

  String? _textOrNull(String raw) {
    final v = raw.trim();
    return v.isEmpty ? null : v;
  }

  int? _intOrNull(String raw) => int.tryParse(raw.trim());

  double? _doubleOrNull(String raw) => double.tryParse(raw.trim());

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Scaffold(
      appBar: StorylokaTopBar(
        title: widget.bookId == null ? 'Tambah Buku' : 'Edit Buku',
        showBack: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            children: [
              // ---- Sampul --------------------------------------------------
              Center(
                child: InkWell(
                  borderRadius: AppRadius.mediumAll,
                  onTap: () => _showCoverSheet(context),
                  child: BookCover(
                    path: _coverPath ?? _coverUrl.text,
                    width: 120,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.micro),
              Center(
                child: Text(
                  'Ketuk untuk ganti sampul',
                  style: AppTypography.caption.copyWith(color: p.neutral500),
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // ---- Field wajib --------------------------------------------
              TextFormField(
                key: const ValueKey<String>('field-title'),
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Judul *',
                  hintText: 'Judul buku',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Judul wajib diisi.' : null,
              ),
              const SizedBox(height: AppSpacing.cardGap),
              TextFormField(
                key: const ValueKey<String>('field-author'),
                controller: _author,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Penulis',
                  hintText: 'Nama penulis',
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              TextFormField(
                key: const ValueKey<String>('field-pages'),
                controller: _pages,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Halaman *',
                  hintText: 'mis. 320',
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n < 1) {
                    return 'Jumlah halaman minimal 1.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // ---- Field opsional -----------------------------------------
              TextFormField(
                key: const ValueKey<String>('field-publisher'),
                controller: _publisher,
                decoration: const InputDecoration(labelText: 'Penerbit'),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey<String>('field-year'),
                      controller: _year,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tahun Terbit'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.cardGap),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey<String>('field-price'),
                      controller: _price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Harga (Rp)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.cardGap),
              TextFormField(
                key: const ValueKey<String>('field-isbn'),
                controller: _isbn,
                decoration: const InputDecoration(labelText: 'ISBN'),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              TextFormField(
                key: const ValueKey<String>('field-genre'),
                controller: _genre,
                decoration: const InputDecoration(labelText: 'Genre'),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              TextFormField(
                key: const ValueKey<String>('field-cover-url'),
                controller: _coverUrl,
                decoration: const InputDecoration(
                  labelText: 'URL Sampul (opsional)',
                  hintText: 'https://…',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // ---- Status ---------------------------------------------------
              Text('Status', style: AppTypography.body1),
              const SizedBox(height: AppSpacing.micro),
              Wrap(
                spacing: AppSpacing.grid,
                children: [
                  for (final status in BookStatus.values)
                    ChoiceChip(
                      label: Text(status.label),
                      selected: _status == status,
                      onSelected: (_) => setState(() => _status = status),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.cardGap),

              if (_error != null)
                Text(
                  _error!,
                  key: const ValueKey<String>('save-error'),
                  style: AppTypography.body2.copyWith(color: p.danger500),
                ),
              const SizedBox(height: AppSpacing.grid),

              // ---- Aksi -----------------------------------------------------
              PrimaryButton(
                key: const ValueKey<String>('save-book'),
                label: 'Simpan Buku',
                loading: _saving,
                onPressed: _save,
              ),
              const SizedBox(height: AppSpacing.grid),
              SecondaryButton(
                label: 'Batal',
                onPressed: _saving ? null : () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCoverSheet(BuildContext context) {
    final p = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      // Root navigator agar sheet selalu berada di atas layer bawah.
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil dengan Kamera'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickCover(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickCover(ImageSource.gallery);
              },
            ),
            if (_coverPath != null || _coverUrl.text.isNotEmpty)
              ListTile(
                leading: Icon(Icons.delete_outline, color: p.danger500),
                title: Text('Hapus Sampul', style: TextStyle(color: p.danger500)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() {
                    _coverPath = null;
                    _coverUrl.clear();
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}
