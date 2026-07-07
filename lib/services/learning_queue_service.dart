import 'dart:math';
import '../models/word.dart';
import '../repositories/word_repository.dart';
import '../utils/constants.dart';

/// An entry waiting to be re-shown after the user pressed "Quên".
class _ForgotEntry {
  final Word word;
  final int revealAtCount; // session question-counter value it becomes eligible at
  _ForgotEntry(this.word, this.revealAtCount);
}

/// Implements the "Infinite Learning" queue described in the spec:
///
///   Priority 1: words due today (SM-2)
///   Priority 2: brand new words
///   Priority 3: Random Review (once due+new are exhausted)
///
/// plus the "Quên" requeue rule (reappear after 8-12 other questions,
/// ~20% mix-in rate) and the Random Review no-repeat cooldown
/// (30-50 questions between repeats, auto-shrunk for small decks).
///
/// This class holds only *session* state (in-memory) - it is not
/// persisted, which is fine because it only affects short-term ordering;
/// the actual SRS truth (due dates, ease factor, etc.) always lives in
/// the database via [WordRepository].
class LearningQueueService {
  final WordRepository wordRepository;
  final Random _random;

  List<String> _activeDeckIds = [];
  final List<_ForgotEntry> _forgotQueue = [];
  final List<String> _recentHistory = []; // word ids, most-recent last
  int _questionCounter = 0;

  LearningQueueService({required this.wordRepository, Random? random})
      : _random = random ?? Random();

  void setActiveDecks(List<String> deckIds) {
    if (deckIds.toSet().difference(_activeDeckIds.toSet()).isNotEmpty ||
        _activeDeckIds.toSet().difference(deckIds.toSet()).isNotEmpty) {
      // Deck selection changed - session-local ordering state no longer
      // makes sense, so start fresh (does NOT touch any persisted data).
      _forgotQueue.clear();
      _recentHistory.clear();
      _questionCounter = 0;
    }
    _activeDeckIds = deckIds;
  }

  /// Call after the user pressed "Quên" for [word]. Schedules it to
  /// reappear after a randomised 8-12 (auto-shrunk) question gap.
  void scheduleForgotRequeue(Word word, {required int approxPoolSize}) {
    final maxGap = approxPoolSize < AppConstants.forgotRequeueMin
        ? max(1, approxPoolSize)
        : AppConstants.forgotRequeueMax;
    final minGap = min(AppConstants.forgotRequeueMin, maxGap);
    final gap = minGap >= maxGap ? minGap : (minGap + _random.nextInt(maxGap - minGap + 1));
    _forgotQueue.add(_ForgotEntry(word, _questionCounter + gap));
  }

  /// Returns the next word to show, or null if there is truly nothing
  /// in the selected decks at all (empty deck / no decks selected).
  Future<Word?> getNextWord() async {
    if (_activeDeckIds.isEmpty) return null;
    final now = DateTime.now();

    final due = await wordRepository.getDueWords(_activeDeckIds, now);
    final freshWords = await wordRepository.getNewWords(_activeDeckIds);

    final readyForgot = _forgotQueue.where((e) => e.revealAtCount <= _questionCounter).toList();

    final primaryPool = due.isNotEmpty ? due : freshWords;

    Word? chosen;

    if (primaryPool.isNotEmpty && readyForgot.isNotEmpty) {
      if (_random.nextDouble() < AppConstants.newOrDueRatio) {
        chosen = _pickFromPool(primaryPool);
      } else {
        final entry = readyForgot.first;
        _forgotQueue.remove(entry);
        chosen = entry.word;
      }
    } else if (primaryPool.isNotEmpty) {
      chosen = _pickFromPool(primaryPool);
    } else if (readyForgot.isNotEmpty) {
      final entry = readyForgot.first;
      _forgotQueue.remove(entry);
      chosen = entry.word;
    } else {
      // Priority 3: automatic fallback to Random Review. Fully silent -
      // no "session ended" messaging, per spec.
      chosen = await _pickRandomReviewWord();
    }

    if (chosen != null) {
      _questionCounter++;
      _recentHistory.add(chosen.id!);
      // Keep history bounded so it doesn't grow forever during a long
      // infinite-learning session.
      if (_recentHistory.length > 500) {
        _recentHistory.removeRange(0, _recentHistory.length - 500);
      }
    }

    return chosen;
  }

  Word _pickFromPool(List<Word> pool) {
    // Prefer words not shown extremely recently even within the primary
    // pool, for a bit of extra variety; falls back to plain random pick.
    final candidates = pool.where((w) => !_recentHistory.contains(w.id)).toList();
    final effectivePool = candidates.isNotEmpty ? candidates : pool;
    return effectivePool[_random.nextInt(effectivePool.length)];
  }

  Future<Word?> _pickRandomReviewWord() async {
    final learned = await wordRepository.getLearnedWords(_activeDeckIds);
    if (learned.isEmpty) return null;
    if (learned.length == 1) return learned.first;

    final maxPossibleCooldown = learned.length - 1;
    final cooldownMax = min(AppConstants.randomReviewCooldownMax, maxPossibleCooldown);
    final cooldownMin = min(AppConstants.randomReviewCooldownMin, cooldownMax);
    final cooldown = cooldownMin >= cooldownMax
        ? cooldownMin
        : (cooldownMin + _random.nextInt(cooldownMax - cooldownMin + 1));

    final forbidden = _recentHistory.length <= cooldown
        ? _recentHistory.toSet()
        : _recentHistory.sublist(_recentHistory.length - cooldown).toSet();

    var candidates = learned.where((w) => !forbidden.contains(w.id)).toList();
    if (candidates.isEmpty) {
      // Extremely small deck: fall back to "just not the same as the
      // very last one shown" so we never truly repeat back-to-back.
      final lastId = _recentHistory.isNotEmpty ? _recentHistory.last : null;
      candidates = learned.where((w) => w.id != lastId).toList();
      if (candidates.isEmpty) candidates = learned;
    }

    return candidates[_random.nextInt(candidates.length)];
  }

  int get questionsAskedThisSession => _questionCounter;
}
