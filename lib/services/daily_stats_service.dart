import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../utils/date_utils.dart';

/// Tracks per-day counters (words learned for the first time, reviews
/// done, words forgotten) which power the Study Streak, Daily Goal and
/// the "words learned per day" chart on the stats screen.
class DailyStatsService {
  final DatabaseHelper _dbHelper;
  DailyStatsService({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<void> _ensureRow(DatabaseExecutor db, String dateKey) async {
    final rows = await db.query('daily_stats', where: 'date = ?', whereArgs: [dateKey]);
    if (rows.isEmpty) {
      await db.insert('daily_stats', {
        'date': dateKey,
        'learnedCount': 0,
        'reviewedCount': 0,
        'forgotCount': 0,
      });
    }
  }

  Future<void> recordReview({required bool isNewWord, required bool remembered}) async {
    final db = await _dbHelper.database;
    final dateKey = AppDateUtils.dayKey(DateTime.now());
    await db.transaction((txn) async {
      await _ensureRow(txn, dateKey);
      await txn.rawUpdate(
        'UPDATE daily_stats SET reviewedCount = reviewedCount + 1, '
        'learnedCount = learnedCount + ?, '
        'forgotCount = forgotCount + ? '
        'WHERE date = ?',
        [isNewWord ? 1 : 0, remembered ? 0 : 1, dateKey],
      );
    });
  }

  Future<Map<String, dynamic>> getToday() async {
    final db = await _dbHelper.database;
    final dateKey = AppDateUtils.dayKey(DateTime.now());
    final rows = await db.query('daily_stats', where: 'date = ?', whereArgs: [dateKey]);
    if (rows.isEmpty) {
      return {'date': dateKey, 'learnedCount': 0, 'reviewedCount': 0, 'forgotCount': 0};
    }
    return rows.first;
  }

  /// Last [days] days of stats, oldest first - handy for a bar chart.
  Future<List<Map<String, dynamic>>> getLastNDays(int days) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final keys = List.generate(days, (i) => AppDateUtils.dayKey(now.subtract(Duration(days: days - 1 - i))));
    final placeholders = List.filled(keys.length, '?').join(',');
    final rows = await db.query('daily_stats', where: 'date IN ($placeholders)', whereArgs: keys);
    final byDate = {for (final r in rows) r['date'] as String: r};
    return keys
        .map((k) => byDate[k] ?? {'date': k, 'learnedCount': 0, 'reviewedCount': 0, 'forgotCount': 0})
        .toList();
  }

  /// Number of consecutive days (ending today or yesterday) that have at
  /// least one review recorded.
  Future<int> getStudyStreak() async {
    final db = await _dbHelper.database;
    final rows = await db.query('daily_stats', orderBy: 'date DESC');
    if (rows.isEmpty) return 0;

    final datesWithActivity = rows
        .where((r) => ((r['reviewedCount'] as int?) ?? 0) > 0)
        .map((r) => r['date'] as String)
        .toSet();

    var streak = 0;
    var cursor = DateTime.now();
    // Allow the streak to still count if today has no activity yet but
    // yesterday does (user just hasn't studied today yet).
    if (!datesWithActivity.contains(AppDateUtils.dayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (datesWithActivity.contains(AppDateUtils.dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
