/// App-wide constants. Centralised here so magic numbers described in the
/// product spec (8-12 câu, 30-50 câu, 80/20 ratio...) are named and easy
/// to tune in one place instead of being scattered through the code.
class AppConstants {
  const AppConstants._();

  /// After "Quên", the word must reappear after this many *other*
  /// questions have been shown (randomised each time within the range).
  static const int forgotRequeueMin = 8;
  static const int forgotRequeueMax = 12;

  /// Minimum gap (in number of other questions asked) before the same
  /// word can reappear during Random Review.
  static const int randomReviewCooldownMin = 30;
  static const int randomReviewCooldownMax = 50;

  /// Target ratio of new/due words vs. forgot-requeue words that the
  /// queue tries to maintain (roughly 80% / 20%).
  static const double newOrDueRatio = 0.8;

  static const int defaultDailyGoal = 20;
}
