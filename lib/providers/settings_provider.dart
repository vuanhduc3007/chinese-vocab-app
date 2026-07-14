import 'package:flutter/foundation.dart';
import '../services/simple_prefs.dart';

/// App-wide user preferences: dark mode and the daily learning goal.
/// Persisted via [SimplePrefs] (a tiny JSON-file key-value store) so no
/// extra plugin dependency is required for something this small.
class SettingsProvider extends ChangeNotifier {
  bool isDarkMode = true;
  int dailyGoal = 20;
  String learningMode = 'recognition'; // 'recognition', 'typing', 'drawing'
  String? geminiApiKey;

  Future<void> load() async {
    final prefs = await SimplePrefs.instance();
    isDarkMode = prefs.getBool('isDarkMode') ?? true;
    dailyGoal = prefs.getInt('dailyGoal') ?? 20;
    learningMode = prefs.getString('learningMode') ?? 'recognition';
    geminiApiKey = prefs.getString('geminiApiKey');
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

  Future<void> setLearningMode(String value) async {
    learningMode = value;
    notifyListeners();
    final prefs = await SimplePrefs.instance();
    await prefs.setString('learningMode', value);
  }

  Future<void> setGeminiApiKey(String? value) async {
    geminiApiKey = value;
    notifyListeners();
    final prefs = await SimplePrefs.instance();
    if (value == null || value.isEmpty) {
      // Assuming SimplePrefs doesn't have remove, we just save empty
      await prefs.setString('geminiApiKey', '');
    } else {
      await prefs.setString('geminiApiKey', value);
    }
  }
}
