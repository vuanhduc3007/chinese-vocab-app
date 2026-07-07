import 'package:flutter/foundation.dart';
import '../repositories/word_repository.dart';
import '../services/daily_stats_service.dart';

/// Aggregates everything shown on the Statistics screen. Pulls from the
/// word repository (totals, accuracy...) and the daily-stats service
/// (streak, today's counters, chart data) and exposes plain fields the
/// UI can bind to directly.
class StatsProvider extends ChangeNotifier {
  final WordRepository wordRepository;
  final DailyStatsService dailyStatsService;

  StatsProvider({required this.wordRepository, required this.dailyStatsService});

  int total = 0;
  int learned = 0;
  int notLearned = 0;
  int mastered = 0;
  int dueToday = 0;
  int dueTomorrow = 0;
  int totalReviews = 0;
  double accuracy = 0;
  int studyStreak = 0;
  int learnedToday = 0;
  int forgotToday = 0;
  int dailyGoal = 20;
  List<Map<String, dynamic>> last14Days = [];

  bool isLoading = false;

  Future<void> load(List<String> deckIds, {int dailyGoalValue = 20}) async {
    isLoading = true;
    notifyListeners();
    dailyGoal = dailyGoalValue;

    if (deckIds.isEmpty) {
      total = learned = notLearned = mastered = dueToday = dueTomorrow = totalReviews = 0;
      accuracy = 0;
      studyStreak = 0;
      learnedToday = forgotToday = 0;
      last14Days = [];
      isLoading = false;
      notifyListeners();
      return;
    }

    total = await wordRepository.countTotal(deckIds);
    learned = await wordRepository.countLearned(deckIds);
    notLearned = total - learned;
    mastered = await wordRepository.countMastered(deckIds);
    dueToday = await wordRepository.countDueOn(deckIds, DateTime.now());
    dueTomorrow = await wordRepository.countDueOn(deckIds, DateTime.now().add(const Duration(days: 1)));

    totalReviews = await wordRepository.sumReviewCount(deckIds);
    final totalCorrect = await wordRepository.sumCorrectCount(deckIds);
    accuracy = totalReviews == 0 ? 0 : (totalCorrect / totalReviews) * 100;

    studyStreak = await dailyStatsService.getStudyStreak();
    final today = await dailyStatsService.getToday();
    learnedToday = today['learnedCount'] as int? ?? 0;
    forgotToday = today['forgotCount'] as int? ?? 0;

    last14Days = await dailyStatsService.getLastNDays(14);

    isLoading = false;
    notifyListeners();
  }

  double get dailyGoalProgress => dailyGoal == 0 ? 0 : (learnedToday / dailyGoal).clamp(0, 1).toDouble();
}
