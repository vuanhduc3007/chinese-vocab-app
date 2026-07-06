import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/deck_provider.dart';
import '../../providers/learning_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/settings_provider.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _lastWordsShown = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wordsShown = context.watch<LearningProvider>().wordsShownThisRun;

    if (wordsShown != _lastWordsShown) {
      _lastWordsShown = wordsShown;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final deckIds = context.read<DeckProvider>().activeDeckIds.toList();
        final dailyGoal = context.read<SettingsProvider>().dailyGoal;
        context.read<StatsProvider>().load(deckIds, dailyGoalValue: dailyGoal);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsProvider>();

    if (stats.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê')),
      body: RefreshIndicator(
        onRefresh: () async {
          final deckIds = context.read<DeckProvider>().activeDeckIds.toList();
          final dailyGoal = context.read<SettingsProvider>().dailyGoal;
          await context.read<StatsProvider>().load(deckIds, dailyGoalValue: dailyGoal);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statGrid(stats),
            const SizedBox(height: 24),
            Text('Mục tiêu hôm nay', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: stats.dailyGoalProgress, minHeight: 12),
            const SizedBox(height: 4),
            Text('${stats.learnedToday} / ${stats.dailyGoal} từ mới'),
            const SizedBox(height: 24),
            Text('Số từ ôn theo ngày (14 ngày gần nhất)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(height: 200, child: _buildChart(stats)),
          ],
        ),
      ),
    );
  }

  Widget _statGrid(StatsProvider stats) {
    final items = <String, String>{
      'Tổng số từ': '${stats.total}',
      'Đã học': '${stats.learned}',
      'Chưa học': '${stats.notLearned}',
      'Đã thuộc': '${stats.mastered}',
      'Đến hạn hôm nay': '${stats.dueToday}',
      'Đến hạn ngày mai': '${stats.dueTomorrow}',
      'Tổng số lần ôn': '${stats.totalReviews}',
      'Accuracy': '${stats.accuracy.toStringAsFixed(1)}%',
      'Study Streak': '${stats.studyStreak} ngày',
      'Học hôm nay': '${stats.learnedToday} từ',
      'Quên hôm nay': '${stats.forgotToday} từ',
    };

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      children: items.entries
          .map((e) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(e.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(e.key, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildChart(StatsProvider stats) {
    final days = stats.last14Days;
    if (days.isEmpty) return const SizedBox();

    final bars = <BarChartGroupData>[];
    for (var i = 0; i < days.length; i++) {
      final count = (days[i]['reviewedCount'] as int?) ?? 0;
      bars.add(
        BarChartGroupData(x: i, barRods: [BarChartRodData(toY: count.toDouble(), width: 10)]),
      );
    }

    return BarChart(
      BarChartData(
        barGroups: bars,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days.length) return const SizedBox();
                final key = days[i]['date'] as String;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(key.substring(5), style: const TextStyle(fontSize: 9)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true),
      ),
    );
  }
}
