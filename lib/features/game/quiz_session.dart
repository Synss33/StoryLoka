import 'question_bank.dart';

/// Status jawaban pada satu soal kuis (untuk warna pilihan SCR-16).
enum AnswerFeedback { correct, wrong, timeout }

/// Mesin kuis Book Trivia — state murni tanpa UI (mudah diuji unit).
///
/// Satu [QuizSession] = satu ronde 10 soal. Jawaban dihitung skor/koin
/// mengikuti `QuestionBank.scorePerCorrect` / `coinsPerCorrect`.
class QuizSession {
  QuizSession({required List<TriviaQuestion> questions})
      : assert(questions.length >= QuestionBank.roundSize,
            'Ronde membutuhkan ≥ ${QuestionBank.roundSize} soal'),
        questions = List<TriviaQuestion>.unmodifiable(questions);

  /// Soal ronde berurutan (sudah diacak oleh bank).
  final List<TriviaQuestion> questions;

  int _index = 0;
  int _correct = 0;
  int? _selected;
  AnswerFeedback? _feedback;
  bool _finished = false;

  /// Indeks soal aktif (0-based).
  int get index => _index;

  /// Soal yang sedang ditampilkan.
  TriviaQuestion get current => questions[_index];

  /// Nomor soal untuk UI (1-based); 0 bila ronde selesai.
  int get displayNumber => _finished ? 0 : _index + 1;

  /// Jumlah benar sejauh ini.
  int get correctCount => _correct;

  /// Opsi yang dipilih pengguna pada soal aktif; `null` bila belum/timer.
  int? get selected => _selected;

  /// Umpan balik soal aktif setelah dijawab; `null` saat masih bermain.
  AnswerFeedback? get feedback => _feedback;

  /// true bila seluruh soal sudah dijawab.
  bool get isFinished => _finished;

  /// Progres 0…1 untuk indikator (n/10).
  double get progress =>
      questions.isEmpty ? 0 : _index / questions.length;

  /// Skor kumulatif (100 × benar — keputusan WF-09).
  int get score => _correct * QuestionBank.scorePerCorrect;

  /// Koin kumulatif (10 × benar — keputusan WF-09).
  int get coins => _correct * QuestionBank.coinsPerCorrect;

  /// Menjawab soal aktif dengan indeks [optionIndex].
  ///
  /// Bila sudah dijawab atau ronde selesai, aksi diabaikan (idempoten).
  /// Mengembalikan true bila jawaban diterima.
  bool answer(int optionIndex) {
    if (_finished || _feedback != null) return false;
    if (optionIndex < 0 || optionIndex >= current.options.length) return false;
    _selected = optionIndex;
    final benar = optionIndex == current.correctIndex;
    if (benar) _correct++;
    _feedback = benar ? AnswerFeedback.correct : AnswerFeedback.wrong;
    return true;
  }

  /// Menandai soal aktif habis waktu (tanpa pilihan pengguna).
  bool timeout() {
    if (_finished || _feedback != null) return false;
    _selected = null;
    _feedback = AnswerFeedback.timeout;
    return true;
  }

  /// Lanjut ke soal berikutnya; true bila masih ada soal.
  ///
  /// Bila soal terakhir → menandai ronde selesai dan mengembalikan false.
  bool next() {
    if (_finished) return false;
    if (_feedback == null) return false; // belum dijawab
    if (_index >= questions.length - 1) {
      _finished = true;
      return false;
    }
    _index++;
    _selected = null;
    _feedback = null;
    return true;
  }
}
