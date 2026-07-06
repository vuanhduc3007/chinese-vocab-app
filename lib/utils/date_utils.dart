/// Small date helpers shared across services (kept separate from business
/// logic so they can be unit-tested trivially and reused anywhere).
class AppDateUtils {
  const AppDateUtils._();

  /// Canonical "yyyy-MM-dd" string used as a stable key for day-level
  /// aggregates (daily_stats table, streaks, "reviewed today" checks...).
  static String dayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);
}
