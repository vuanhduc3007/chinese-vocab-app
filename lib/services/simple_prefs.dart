import 'dart:convert';
import 'simple_prefs_io.dart' if (dart.library.html) 'simple_prefs_web.dart' as platform;

/// Minimal persisted key-value store backed by a small JSON file (on native)
/// or localStorage (on web).
class SimplePrefs {
  SimplePrefs.internal(this._data, this._saveFn);

  final Map<String, dynamic> _data;
  final Future<void> Function(String json) _saveFn;

  static SimplePrefs? _instance;

  static Future<SimplePrefs> instance() async {
    if (_instance != null) return _instance!;
    _instance = await platform.createSimplePrefs();
    return _instance!;
  }

  Future<void> _save() async {
    await _saveFn(jsonEncode(_data));
  }

  bool? getBool(String key) => _data[key] as bool?;
  int? getInt(String key) => _data[key] as int?;
  String? getString(String key) => _data[key] as String?;

  Future<void> setBool(String key, bool value) async {
    _data[key] = value;
    await _save();
  }

  Future<void> setInt(String key, int value) async {
    _data[key] = value;
    await _save();
  }

  Future<void> setString(String key, String value) async {
    _data[key] = value;
    await _save();
  }
}
