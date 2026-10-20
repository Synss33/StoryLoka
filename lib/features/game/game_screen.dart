import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/book_repository.dart';
import '../../core/db/database_provider.dart';
import '../../core/db/game_score_repository.dart';
import '../../core/models/book.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/storyloka_card.dart';
import '../../core/widgets/top_bar.dart';
import '../../features/auth/auth_controller.dart';
import 'question_bank.dart';
import 'quiz_session.dart';

/// SCR-16 — Permainan Book Trivia (F-13 · WF-09).
///
/// 10 soal pilihan ganda, timer 15 detik/soal berbasis timestamp,
/// skor → koin, hasil tersimpan di `game_scores` (skor tertinggi +
/// total koin untuk segmen Game SCR-04 & statistik SCR-09).
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({
    super.key,
    this.questionSeconds,
    this.questionsOverride,
  });

  /// Durasi per soal (detik); disuntik untuk pengujian (default 15).
  final int? questionSeconds;

  /// Soal ronde tetap; disuntik untuk pengujian deterministik (TC-28).
  /// `null` → bank acak dari koleksi + bank lokal.
  final List<TriviaQuestion>? questionsOverride;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  QuizSession? _session;
  List<Book> _books = const <Book>[];
  bool _loading = true;
  bool _saving = false;

  /// Epoch ms saat soal aktif dimulai (dasar timer timestamp).
  int _questionStartMs = 0;
  int _remainingSec = 0;
  Timer? _ticker;

  int? _bestScore;
  int _totalCoins = 0;
  int? _lastScore;
  int? _lastCoins;
  bool _isBest = false;

  int get _secondsPerQuestion =>
      widget.questionSeconds ?? QuestionBank.secondsPerQuestion;

  @override
  void initState() {
    super.initState();
    // Muat koleksi + rekor tanpa menunggu frame pertama (hindari flicker).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final userId = ref.read(authControllerProvider).userId;
    final db = await ref.read(databaseProvider.future);
    if (!mounted || userId == null || db == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final books = await BookRepository(db).list(userId);
    final repo = GameScoreRepository(db);
    final best = await repo.bestScore(userId);
    final coins = await repo.totalCoins(userId);
    if (!mounted) return;
    setState(() {
      _books = books;
      _bestScore = best;
      _totalCoins = coins;
      _loading = false;
    });
  }

  void _startRound() {
    _ticker?.cancel();
    final override = widget.questionsOverride;
    final round = override != null && override.length >= QuestionBank.roundSize
        ? override
        : QuestionBank.buildRound(books: _books);
    setState(() {
      _session = QuizSession(questions: round);
      _lastScore = null;
      _lastCoins = null;
      _isBest = false;
      _questionStartMs = DateTime.now().millisecondsSinceEpoch;
      _remainingSec = _secondsPerQuestion;
    });
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final session = _session;
      if (session == null || session.isFinished || session.feedback != null) {
        return;
      }
      final elapsedMs =
          DateTime.now().millisecondsSinceEpoch - _questionStartMs;
      final left = _secondsPerQuestion - elapsedMs ~/ 1000;
      if (left != _remainingSec) {
        setState(() => _remainingSec = left < 0 ? 0 : left);
      }
      if (left <= 0) {
        _onTimeout();
      }
    });
  }

  Future<void> _onTimeout() async {
    final session = _session;
    if (session == null || session.feedback != null) return;
    session.timeout();
    // Jangan tunggu kanal platform (host test tak merespons — WF-04).
    unawaited(HapticFeedback.vibrate().catchError((Object _) {}));
    if (!mounted) return;
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await _advance();
  }

  Future<void> _onSelect(int optionIndex) async {
    final session = _session;
    if (session == null || session.feedback != null) return;
    session.answer(optionIndex);
    unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
    if (!mounted) return;
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await _advance();
  }

  Future<void> _advance() async {
    final session = _session;
    if (session == null) return;
    final more = session.next();
    if (!mounted) return;
    if (more) {
      setState(() {
        _questionStartMs = DateTime.now().millisecondsSinceEpoch;
        _remainingSec = _secondsPerQuestion;
      });
      return;
    }
    // Ronde selesai → simpan skor & koin (TC-28).
    await _finishRound();
  }

  Future<void> _finishRound() async {
    final session = _session;
    final userId = ref.read(authControllerProvider).userId;
    final db = await ref.read(databaseProvider.future);
    if (session == null || userId == null || db == null) return;

    setState(() => _saving = true);
    final repo = GameScoreRepository(db);
    final score = session.score;
    final coins = session.coins;
    await repo.save(
      userId: userId,
      score: score,
      coins: coins,
      playedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final best = await repo.bestScore(userId);
    final total = await repo.totalCoins(userId);
    if (!mounted) return;
    setState(() {
      _lastScore = score;
      _lastCoins = coins;
      _bestScore = best;
      _totalCoins = total;
      _isBest = best != null && score >= best && score > 0;
      _saving = false;
    });
  }

  Future<void> _goHome() async {
    // Kembali ke Explore (segmen Game) — rute shell.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/explore');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final session = _session;

    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Book Trivia', showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : session == null
              ? _buildIntro(p)
              : session.isFinished
                  ? _buildResult(p, session)
                  : _buildQuestion(p, session),
    );
  }

  // ---------------------------------------------------------------------------
  // Intro (sebelum ronde)
  // ---------------------------------------------------------------------------

  Widget _buildIntro(AppPalette p) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StorylokaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Book Trivia Challenge', style: AppTypography.h2),
                const SizedBox(height: AppSpacing.grid),
                Text(
                  'Uji pengetahuanmu tentang buku-buku populer. '
                  'Sepuluh soal, $_secondsPerQuestion detik tiap soal — '
                  'jawaban benar menghasilkan koin.',
                  style: AppTypography.body1.copyWith(color: p.neutral500),
                ),
                const SizedBox(height: AppSpacing.cardGap),
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.emoji_events_outlined,
                      label: 'Skor tertinggi',
                      value: _bestScore?.toString() ?? '—',
                    ),
                    const SizedBox(width: AppSpacing.grid),
                    _StatChip(
                      icon: Icons.monetization_on_outlined,
                      label: 'Koin',
                      value: '$_totalCoins',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.screenMargin),
          PrimaryButton(
            key: const ValueKey<String>('start-quiz'),
            label: 'Mulai Kuis',
            onPressed: _startRound,
          ),
          if (_books.isEmpty) ...[
            const SizedBox(height: AppSpacing.grid),
            Text(
              'Tip: tambah buku di koleksi untuk soal tentang bukumu sendiri.',
              style: AppTypography.body2.copyWith(color: p.neutral500),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Soal aktif
  // ---------------------------------------------------------------------------

  Widget _buildQuestion(AppPalette p, QuizSession session) {
    final q = session.current;
    final answered = session.feedback != null;
    final fraction = _secondsPerQuestion <= 0
        ? 0.0
        : (_remainingSec / _secondsPerQuestion).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress (3/10) + timer lingkaran 15 dtk.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Soal ${session.displayNumber}/${session.questions.length}',
                      style: AppTypography.h3,
                    ),
                    const SizedBox(height: AppSpacing.micro),
                    ClipRRect(
                      borderRadius: AppRadius.pillAll,
                      child: LinearProgressIndicator(
                        key: const ValueKey<String>('quiz-progress'),
                        value: session.progress,
                        minHeight: 6,
                        backgroundColor: p.neutral200,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.cardGap),
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      key: const ValueKey<String>('quiz-timer'),
                      value: fraction,
                      strokeWidth: 4,
                      backgroundColor: p.neutral200,
                      color: _remainingSec <= 5 ? p.danger500 : p.primary500,
                    ),
                    Center(
                      child: Text(
                        '$_remainingSec',
                        key: const ValueKey<String>('timer-value'),
                        style: AppTypography.h2.copyWith(
                          color: _remainingSec <= 5 ? p.danger500 : p.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.screenMargin),
          // Kartu pertanyaan.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StorylokaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.category.toUpperCase(),
                          style: AppTypography.caption
                              .copyWith(color: p.primary600),
                        ),
                        const SizedBox(height: AppSpacing.micro),
                        Text(q.prompt, style: AppTypography.h2),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.cardGap),
                  // 4 pilihan jawaban.
                  for (var i = 0; i < q.options.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.grid,
                      ),
                      child: _AnswerTile(
                        label: q.options[i],
                        index: i,
                        state: _tileState(session, i),
                        onTap: answered ? null : () => _onSelect(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _AnswerTileState _tileState(QuizSession session, int i) {
    final fb = session.feedback;
    if (fb == null) {
      return session.selected == i
          ? _AnswerTileState.selected
          : _AnswerTileState.idle;
    }
    // Setelah dijawab: benar → success, salah/timeout → tampilkan benar.
    if (i == session.current.correctIndex) return _AnswerTileState.correct;
    if (session.selected == i) {
      return fb == AnswerFeedback.timeout
          ? _AnswerTileState.timeout
          : _AnswerTileState.wrong;
    }
    return _AnswerTileState.idle;
  }

  // ---------------------------------------------------------------------------
  // Hasil ronde
  // ---------------------------------------------------------------------------

  Widget _buildResult(AppPalette p, QuizSession session) {
    if (_saving) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isBest)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
              child: Text(
                '🎉 Rekor Baru!',
                key: const ValueKey<String>('new-record'),
                style: AppTypography.h2.copyWith(color: p.success500),
                textAlign: TextAlign.center,
              ),
            ),
          StorylokaCard(
            child: Column(
              children: [
                Text('Hasil Kuis', style: AppTypography.h2),
                const SizedBox(height: AppSpacing.cardGap),
                Text(
                  '${session.correctCount}/${session.questions.length}',
                  key: const ValueKey<String>('result-correct'),
                  style: AppTypography.h1.copyWith(color: p.primary600),
                ),
                const SizedBox(height: AppSpacing.micro),
                Text(
                  'jawaban benar',
                  style: AppTypography.body2.copyWith(color: p.neutral500),
                ),
                const SizedBox(height: AppSpacing.cardGap),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatChip(
                      icon: Icons.star_outline,
                      label: 'Skor',
                      value: '${_lastScore ?? session.score}',
                    ),
                    _StatChip(
                      icon: Icons.monetization_on_outlined,
                      label: 'Koin +',
                      value: '${_lastCoins ?? session.coins}',
                    ),
                    _StatChip(
                      icon: Icons.emoji_events_outlined,
                      label: 'Rekor',
                      value: _bestScore?.toString() ?? '—',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.screenMargin),
          PrimaryButton(
            key: const ValueKey<String>('play-again'),
            label: 'Main Lagi',
            onPressed: _startRound,
          ),
          const SizedBox(height: AppSpacing.grid),
          SecondaryButton(
            key: const ValueKey<String>('back-home'),
            label: 'Kembali',
            onPressed: _goHome,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pilihan jawaban
// ---------------------------------------------------------------------------

enum _AnswerTileState { idle, selected, correct, wrong, timeout }

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.label,
    required this.index,
    required this.state,
    required this.onTap,
  });

  final String label;
  final int index;
  final _AnswerTileState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final letter = String.fromCharCode(65 + index); // A–D

    Color border;
    Color? background;
    Color text = p.textPrimary;
    Widget? trailing;
    switch (state) {
      case _AnswerTileState.idle:
        border = p.neutral200;
      case _AnswerTileState.selected:
        border = p.primary500;
        background = p.primary50;
      case _AnswerTileState.correct:
        border = p.success500;
        background = p.success500.withValues(alpha: 0.12);
        trailing = Icon(Icons.check_circle, color: p.success500, size: 20);
      case _AnswerTileState.wrong:
        border = p.danger500;
        background = p.danger500.withValues(alpha: 0.12);
        trailing = Icon(Icons.cancel, color: p.danger500, size: 20);
      case _AnswerTileState.timeout:
        border = p.neutral500;
        text = p.neutral500;
        trailing = Icon(Icons.timer_off, color: p.neutral500, size: 20);
    }

    return Material(
      color: background ?? p.surface,
      borderRadius: AppRadius.mediumAll,
      child: InkWell(
        key: ValueKey<String>('answer-$index'),
        onTap: onTap,
        borderRadius: AppRadius.mediumAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
            vertical: AppSpacing.cardGap,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mediumAll,
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: p.neutral200,
                child: Text(
                  letter,
                  style: AppTypography.caption.copyWith(
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.cardGap),
              Expanded(
                child: Text(label, style: AppTypography.body1.copyWith(color: text)),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.grid),
        decoration: BoxDecoration(
          color: p.neutral100,
          borderRadius: AppRadius.smallAll,
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: p.primary600),
            const SizedBox(height: AppSpacing.micro),
            Text(value, style: AppTypography.h3),
            Text(
              label,
              style: AppTypography.body2.copyWith(color: p.neutral500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
