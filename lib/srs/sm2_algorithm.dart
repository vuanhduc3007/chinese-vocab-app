import '../models/word.dart';

/// Minimum allowed ease factor per the classic SM-2 spec.
const double kMinEaseFactor = 1.3;

/// Interval (in days) a word falls back to right after being forgotten.
/// SM-2 restarts the repetition ladder from the beginning.
const int kRelearnIntervalDays = 1;

/// The two answers the user can give. Mapped internally onto an SM-2
/// "quality" score (0-5 scale) so the rest of the algorithm below is a
/// textbook implementation of SuperMemo-2, not a custom variant.
enum ReviewResult { remembered, forgot }

/// Pure result object returned by [SM2Algorithm.calculate]. Nothing here
/// touches the database or the UI - this module only knows about numbers,
/// so the algorithm can be swapped out later without touching anything
/// else in the app (repositories, providers, UI all depend on [Word]
/// fields only, not on this class).
class SM2Result {
  final double easeFactor;
  final int interval;
  final int repetition;
  final DateTime nextReview;

  const SM2Result({
    required this.easeFactor,
    required this.interval,
    required this.repetition,
    required this.nextReview,
  });
}

/// Independent SM-2 (SuperMemo 2) implementation.
///
/// This class is intentionally the *only* place in the whole codebase
/// that knows the SM-2 formulas. If the SRS algorithm ever needs to be
/// replaced (e.g. with FSRS), only this file needs to change - every
/// caller only interacts with [Word] fields and [ReviewResult].
class SM2Algorithm {
  const SM2Algorithm._();

  /// Maps our binary "Da nho / Quen" answer onto SM-2's 0-5 quality scale.
  /// - Remembered -> 4 ("good": recalled correctly with some effort)
  /// - Forgot     -> 2 ("fail": incorrect, but recognized on being shown)
  static int _qualityFor(ReviewResult result) {
    return result == ReviewResult.remembered ? 4 : 2;
  }

  /// Computes the next SM-2 state for [word] given the user's [result].
  /// [now] is injectable for testability; defaults to [DateTime.now()].
  static SM2Result calculate(Word word, ReviewResult result, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final quality = _qualityFor(result);

    // EF' = EF + (0.1 - (5-q) * (0.08 + (5-q) * 0.02))
    final delta = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02);
    double newEaseFactor = word.easeFactor + delta;
    if (newEaseFactor < kMinEaseFactor) newEaseFactor = kMinEaseFactor;

    int newRepetition;
    int newInterval;

    if (quality < 3) {
      // Failed recall: restart the repetition ladder from zero and fall
      // back to the smallest interval. easeFactor still decays per the
      // formula above (already applied) but never goes below 1.3.
      newRepetition = 0;
      newInterval = kRelearnIntervalDays;
    } else {
      newRepetition = word.repetition + 1;
      if (newRepetition == 1) {
        newInterval = 1;
      } else if (newRepetition == 2) {
        newInterval = 6;
      } else {
        final baseInterval = word.interval <= 0 ? 1 : word.interval;
        newInterval = (baseInterval * newEaseFactor).round();
      }
    }

    final nextReview = _addDays(currentTime, newInterval);

    return SM2Result(
      easeFactor: newEaseFactor,
      interval: newInterval,
      repetition: newRepetition,
      nextReview: nextReview,
    );
  }

  static DateTime _addDays(DateTime from, int days) {
    return from.add(Duration(days: days));
  }
}
