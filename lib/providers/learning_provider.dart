import 'package:flutter/foundation.dart';
import '../models/word.dart';
import '../repositories/word_repository.dart';
import '../services/learning_queue_service.dart';
import '../services/tts_service.dart';
import '../services/daily_stats_service.dart';
import '../srs/sm2_algorithm.dart';

enum CardFace { question, answer }

/// Drives the single "infinite learning" flashcard screen. Everything
/// UI-facing (current word, whether the answer is revealed, button
/// enabled/disabled state) lives here; everything SRS-related is
/// delegated to [SM2Algorithm] and [LearningQueueService] so this class
/// stays a thin coordinator rather than a place where business rules get
/// reinvented.
class LearningProvider extends ChangeNotifier {
  final WordRepository wordRepository;
  final LearningQueueService queueService;
  final TtsService ttsService;
  final DailyStatsService dailyStatsService;

  LearningProvider({
    required this.wordRepository,
    required this.queueService,
    required this.ttsService,
    required this.dailyStatsService,
  });

  Word? currentWord;
  CardFace face = CardFace.question;
  bool isLoadingNext = false;
  int wordsShownThisRun = 0;

  Future<void> setActiveDecks(List<String> deckIds) async {
    queueService.setActiveDecks(deckIds);
    await loadNextWord();
  }

  Future<void> loadNextWord() async {
    isLoadingNext = true;
    notifyListeners();

    final word = await queueService.getNextWord();
    currentWord = word;
    face = CardFace.question;
    if (word != null) {
      currentWord = word.copyWith(lastShown: DateTime.now());
      wordsShownThisRun++;
    }

    isLoadingNext = false;
    notifyListeners();
  }

  void revealAnswer() {
    if (face == CardFace.answer || currentWord == null) return;
    face = CardFace.answer;
    notifyListeners();
    speakCurrentWord();
  }

  Future<void> speakCurrentWord() async {
    final word = currentWord;
    if (word == null) return;
    await ttsService.speak(word.hanzi);
  }

  Future<void> answerRemembered() => _answer(ReviewResult.remembered);

  Future<void> answerForgot() => _answer(ReviewResult.forgot);

  Future<void> _answer(ReviewResult result) async {
    final word = currentWord;
    if (word == null || face != CardFace.answer) return;

    final isNewWord = word.isNew;
    final sm2 = SM2Algorithm.calculate(word, result);

    final updated = word.copyWith(
      reviewCount: word.reviewCount + 1,
      correctCount: result == ReviewResult.remembered ? word.correctCount + 1 : word.correctCount,
      wrongCount: result == ReviewResult.forgot ? word.wrongCount + 1 : word.wrongCount,
      correctStreak: result == ReviewResult.remembered ? word.correctStreak + 1 : 0,
      easeFactor: sm2.easeFactor,
      interval: sm2.interval,
      repetition: sm2.repetition,
      lastReview: DateTime.now(),
      nextReview: sm2.nextReview,
    );

    // Fire and forget network calls so the UI moves to the next card instantly
    wordRepository.updateWord(updated);
    dailyStatsService.recordReview(isNewWord: isNewWord, remembered: result == ReviewResult.remembered);

    if (result == ReviewResult.forgot) {
      wordRepository.countLearned([updated.deckId]).then((poolSize) {
        queueService.scheduleForgotRequeue(updated, approxPoolSize: poolSize);
      }).catchError((_) {});
    }

    await loadNextWord();
  }

  Future<void> toggleFavoriteCurrentWord() async {
    final word = currentWord;
    if (word == null) return;
    final newValue = !word.isFavorite;
    await wordRepository.toggleFavorite(word.id!, newValue);
    currentWord = word.copyWith(isFavorite: newValue);
    notifyListeners();
  }
}
