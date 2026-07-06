import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'simple_prefs.dart';

Future<SimplePrefs> createSimplePrefs() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docsDir.path, 'ChineseVocabApp'));
  if (!await dir.exists()) await dir.create(recursive: true);
  final file = File(p.join(dir.path, 'settings.json'));

  Map<String, dynamic> data = {};
  if (await file.exists()) {
    try {
      data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      data = {};
    }
  } else {
    await file.writeAsString(jsonEncode(data));
  }

  return SimplePrefs.internal(data, (String jsonStr) async {
    await file.writeAsString(jsonStr);
  });
}
