import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/book_repository.dart';
import '../../core/models/book.dart';
import '../../core/network/ai_service.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/top_bar.dart';
import '../../features/auth/auth_store.dart';
import '../../features/book_detail/book_detail_data.dart';

/// Satu gelembung chat di SCR-05.
class _ChatMessage {
  const _ChatMessage({required this.isUser, required this.text});

  final bool isUser;
  final String text;
}

/// SCR-05 - AI / LLM Assistant (F-11 / WF-07).
///
/// Alur (workflow 3.5): prompt (+ konteks buku bila dibuka dari SCR-06) ->
/// `POST /ai/chat` (token sesi) -> balasan + label "Dihasilkan AI".
/// State: AI mengetik (tiga titik), galat/timeout -> Coba Lagi, kuota ->
/// pesan jelas, offline -> input dinonaktifkan (TC-25).
class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key, this.bookId});

  /// Buku konteks - dikirim dari SCR-06 ("Tanya AI") lewat `?book=<id>`.
  final int? bookId;

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<_ChatMessage> _messages = <_ChatMessage>[];

  bool _online = true;
  bool _sending = false;
  String? _error;
  Future<void> Function()? _retry;
  String? _token;
  int? _userId;
  Book? _contextBook;
  List<String> _contextNotes = const <String>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_init);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Cek koneksi, muat token, dan (bila dibuka dari SCR-06) konteks buku.
  Future<void> _init() async {
    final store = ref.read(authStoreProvider);
    final session = await store.readSession();
    final token = await onlineTokenOf(store);
    final health = await ref.read(apiClientProvider).getHealth();
    if (!mounted) return;
    setState(() {
      _token = token;
      _userId = session?.userId;
      _online = health.ok;
    });

    if (widget.bookId == null) return;
    final detail = await ref.read(bookDetailProvider(widget.bookId!).future);
    if (!mounted || detail == null) return;
    setState(() {
      _contextBook = detail.book;
      _contextNotes = detail.notes.take(5).map((n) => n.content).toList();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  String? get _contextLabel {
    final book = _contextBook;
    if (book == null) return null;
    final notes = _contextNotes.isEmpty
        ? ''
        : ' Catatan pembaca: ${_contextNotes.join(" | ")}.';
    return 'Judul: ${book.title} - Penulis: ${book.author}.$notes';
  }

  /// Riwayat percakapan (maks 8 langkah terakhir) untuk konteks server.
  List<Map<String, String>> _history() {
    final all = _messages.toList();
    final recent = all.length > 8 ? all.sublist(all.length - 8) : all;
    return recent
        .map((m) => <String, String>{
              'role': m.isUser ? 'user' : 'assistant',
              'text': m.text,
            })
        .toList();
  }

  /// Satu langkah aksi AI: tampilkan label user -> kirim -> balasan/galat.
  Future<void> _runAction({
    required String label,
    required Future<AiResult> Function() action,
    Future<void> Function()? onRetry,
  }) async {
    if (_sending) return;
    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: label));
      _sending = true;
      _error = null;
      _retry = null;
    });
    _scrollToBottom();

    final result = await action();
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result.ok) {
        _messages.add(_ChatMessage(isUser: false, text: result.text!));
      } else {
        if (result.failure == AiFailure.offline) _online = false;
        _error = result.message;
        _retry = onRetry;
      }
    });
    _scrollToBottom();
  }

  Future<void> _sendChat(String message) async {
    final text = message.trim();
    if (text.isEmpty) return;
    _input.clear();
    await _runAction(
      label: text,
      onRetry: () => _sendChat(text),
      action: () => ref.read(aiServiceProvider).chat(
            message: text,
            history: _history(),
            context: _contextLabel,
            token: _token,
          ),
    );
  }

  Future<void> _quickSummarize() async {
    final book = _contextBook;
    await _runAction(
      label: book == null
          ? 'Ringkas buku yang sedang saya baca'
          : 'Ringkas ${book.title}',
      onRetry: _quickSummarize,
      action: () => ref.read(aiServiceProvider).summarize(
            title: book?.title ?? 'Buku saya',
            author: book?.author,
            synopsis: book?.synopsis,
            notes: _contextNotes,
            token: _token,
          ),
    );
  }

  Future<void> _quickRecommend() async {
    await _runAction(
      label: 'Rekomendasi buku mirip dari koleksi saya',
      onRetry: _quickRecommend,
      action: () async {
        final userId = _userId;
        final repo = await ref.read(bookRepositoryProvider.future);
        final books = <Map<String, Object?>>[];
        if (userId != null && repo != null) {
          final own = await repo.list(userId);
          for (final book in own.take(20)) {
            books.add(<String, Object?>{
              'title': book.title,
              'author': book.author,
              'genre': book.genre,
              'rating': book.rating,
            });
          }
        }
        return ref.read(aiServiceProvider).recommend(
              books: books,
              token: _token,
            );
      },
    );
  }

  Future<void> _quickExplain() async {
    final book = _contextBook;
    final text = book == null
        ? 'Jelaskan tema dan karakter utama buku yang sedang saya baca'
        : 'Jelaskan tema dan karakter utama ${book.title}';
    await _runAction(
      label: text,
      onRetry: _quickExplain,
      action: () => ref.read(aiServiceProvider).chat(
            message: text,
            context: _contextLabel,
            token: _token,
          ),
    );
  }

  Future<void> _retryLast() async {
    final retry = _retry;
    setState(() {
      _error = null;
      _retry = null;
    });
    if (retry != null) await retry();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: StorylokaTopBar(
        title: 'Storyloka AI',
        showBack: true,
        actions: [_statusChip(colors)],
      ),
      body: Column(
        children: [
          _quickActions(colors),
          if (!_online) _offlineBanner(colors),
          Expanded(child: _messageList(colors)),
          if (_sending) _typingIndicator(colors),
          if (_error != null) _errorBox(colors),
          _inputRow(colors),
        ],
      ),
    );
  }

  /// Status koneksi di Top Bar: "Online" / "Offline" (desain SCR-05).
  Widget _statusChip(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.grid),
      child: Center(
        child: Container(
          key: const ValueKey<String>('ai-status'),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.grid,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: _online ? colors.success500 : colors.danger500,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            _online ? 'Online' : 'Offline',
            style: AppTypography.caption.copyWith(color: colors.onPrimary),
          ),
        ),
      ),
    );
  }

  /// Quick action: Ringkasan / Buku Mirip / Jelaskan (desain SCR-05).
  Widget _quickActions(AppPalette colors) {
    Widget chip(String label, VoidCallback onTap) {
      return ActionChip(
        label: Text(label),
        onPressed: _online && !_sending ? onTap : null,
        backgroundColor: colors.primary50,
        side: BorderSide.none,
        labelStyle: AppTypography.body2.copyWith(color: colors.primary600),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.grid,
        AppSpacing.screenMargin,
        AppSpacing.micro,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip('Ringkasan', _quickSummarize),
            const SizedBox(width: AppSpacing.grid),
            chip('Buku Mirip', _quickRecommend),
            const SizedBox(width: AppSpacing.grid),
            chip('Jelaskan', _quickExplain),
          ],
        ),
      ),
    );
  }

  Widget _offlineBanner(AppPalette colors) {
    return Container(
      key: const ValueKey<String>('ai-offline'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
      padding: const EdgeInsets.all(AppSpacing.grid),
      decoration: BoxDecoration(
        color: colors.danger500.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Text(
        'Offline - sambungkan internet untuk mengirim pertanyaan.',
        style: AppTypography.body2.copyWith(color: colors.danger500),
      ),
    );
  }

  Widget _messageList(AppPalette colors) {
    if (_messages.isEmpty && !_sending) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 40,
                color: colors.secondary500,
              ),
              const SizedBox(height: AppSpacing.grid),
              Text(
                widget.bookId == null
                    ? 'Tanya apa saja seputar buku, atau pilih aksi cepat di atas.'
                    : 'Konteks buku aktif. Tanya karakter, tema, atau ringkas buku ini.',
                textAlign: TextAlign.center,
                style: AppTypography.body1.copyWith(color: colors.neutral500),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _bubble(_messages[index], colors),
    );
  }

  /// Gelembung chat: user (kanan, primary-500) / AI (kiri, neutral-100)
  /// dengan label "Dihasilkan AI" (desain SCR-05).
  Widget _bubble(_ChatMessage message, AppPalette colors) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: ValueKey<String>(isUser ? 'ai-user-bubble' : 'ai-bubble'),
        margin: const EdgeInsets.only(bottom: AppSpacing.grid),
        padding: const EdgeInsets.all(AppSpacing.grid),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? colors.primary500 : colors.neutral100,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: AppTypography.body1.copyWith(
                color: isUser ? colors.onPrimary : colors.textPrimary,
              ),
            ),
            if (!isUser) ...[
              const SizedBox(height: AppSpacing.micro),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 12,
                    color: colors.secondary500,
                  ),
                  const SizedBox(width: AppSpacing.micro),
                  Text(
                    'Dihasilkan AI',
                    key: const ValueKey<String>('ai-label'),
                    style: AppTypography.caption.copyWith(
                      color: colors.neutral500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Indikator "AI mengetik" (tiga titik, desain SCR-05).
  Widget _typingIndicator(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.screenMargin,
        bottom: AppSpacing.micro,
      ),
      child: Row(
        children: [
          Container(
            key: const ValueKey<String>('ai-typing'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.grid,
              vertical: AppSpacing.micro,
            ),
            decoration: BoxDecoration(
              color: colors.neutral100,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Text('. . .', style: AppTypography.body2),
          ),
        ],
      ),
    );
  }

  /// Galat permintaan + tombol "Coba Lagi" (TC-25).
  Widget _errorBox(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.micro),
      child: Column(
        children: [
          Text(
            _error!,
            key: const ValueKey<String>('ai-error-text'),
            textAlign: TextAlign.center,
            style: AppTypography.body2.copyWith(color: colors.danger500),
          ),
          if (_retry != null)
            TextButton.icon(
              key: const ValueKey<String>('ai-retry'),
              onPressed: _retryLast,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba Lagi'),
            ),
        ],
      ),
    );
  }

  /// Baris input + tombol Kirim; dinonaktifkan saat offline (TC-25).
  Widget _inputRow(AppPalette colors) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey<String>('ai-input'),
                controller: _input,
                enabled: _online,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendChat(_input.text),
                decoration: InputDecoration(
                  hintText: 'Tulis pertanyaan...',
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.grid),
            // themed FilledButton memakai minimumSize lebar-penuh (tinggi 48);
            // di dalam Row dibatasi dulu agar tidak menerima lebar infinite.
            SizedBox(
              width: 96,
              child: FilledButton(
                key: const ValueKey<String>('ai-send'),
                onPressed: _online && !_sending
                    ? () => _sendChat(_input.text)
                    : null,
                child: const Text('Kirim'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
