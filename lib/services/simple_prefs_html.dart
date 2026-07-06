import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'simple_prefs.dart';

const _storageKey = 'chinese_vocab_app_settings';

/// Creates a [SimplePrefs] instance backed by `window.localStorage`.
/// Used on the web platform.
Future<SimplePrefs> createSimplePrefs() async {
  Map<String, dynamic> data = {};
  final stored = html.window.localStorage[_storageKey];
  if (stored != null && stored.isNotEmpty) {
    try {
      data = jsonDecode(stored) as Map<String, dynamic>;
    } catch (_) {
      data = {};
    }
  }

  return SimplePrefs.fromPlatform(
    data,
    (json) async => html.window.localStorage[_storageKey] = json,
  );
}
