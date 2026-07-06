import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> exportProgressFile(Map<String, dynamic> payload) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final exportDir = Directory(p.join(docsDir.path, 'ChineseVocabApp', 'exports'));
  if (!await exportDir.exists()) await exportDir.create(recursive: true);

  final fileName = 'progress_backup_${DateTime.now().millisecondsSinceEpoch}.json';
  final file = File(p.join(exportDir.path, fileName));
  await file.writeAsString(jsonEncode(payload));
  return file.path;
}

Future<String> backupDatabaseFileIo() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final dbDir = Directory(p.join(docsDir.path, 'ChineseVocabApp'));
  final dbFile = File(p.join(dbDir.path, 'chinese_vocab.db'));
  if (!await dbFile.exists()) {
    throw Exception('Database file not found yet.');
  }

  final backupDir = Directory(p.join(dbDir.path, 'auto_backups'));
  if (!await backupDir.exists()) await backupDir.create(recursive: true);

  final backupPath = p.join(backupDir.path, 'db_backup_${DateTime.now().millisecondsSinceEpoch}.db');
  await dbFile.copy(backupPath);

  final files = backupDir.listSync().whereType<File>().toList()
    ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  for (final f in files.skip(10)) {
    await f.delete();
  }

  return backupPath;
}
