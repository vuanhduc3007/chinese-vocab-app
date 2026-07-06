import 'dart:convert';
import 'dart:html' as html;
import 'simple_prefs.dart';

Future<SimplePrefs> createSimplePrefs() async {
  Map<String, dynamic> data = {};
  final stored = html.window.localStorage['chinese_vocab_settings'];
  if (stored != null) {
    try {
      data = jsonDecode(stored) as Map<String, dynamic>;
    } catch (_) {
      data = {};
    }
  }

  return SimplePrefs.internal(data, (String jsonStr) async {
    html.window.localStorage['chinese_vocab_settings'] = jsonStr;
  });
}
