import 'package:flutter/foundation.dart';
import '../services/simple_prefs.dart';

/// App-wide user preferences: dark mode and the daily learning goal.
/// Persisted via [SimplePrefs] (a tiny JSON-file key-value store) so no
/// extra plugin dependency is required for something this small.
class SettingsProvider extends ChangeNotifier {
  bool isDarkMode = true;
  int dailyGoal = 20;

  Future<void> load() async {
    final prefs = await SimplePrefs.instance();
    isDarkMode = prefs.getBool('isDarkMode') ?? true;
    dailyGoal = prefs.getInt('dailyGoal') ?? 20;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    isDarkMode = value;
    notifyListeners();
    final prefs = await SimplePrefs.instance();
    await prefs.setBool('isDarkMode', value);
  }

  Future<void> setDailyGoal(int value) async {
    dailyGoal = value;
    notifyListeners();
    final prefs = await SimplePrefs.instance();
    await prefs.setInt('dailyGoal', value);
  }
}
