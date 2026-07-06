import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

bool get isDesktop =>
    !Platform.isAndroid && !Platform.isIOS && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

Future<String> getDatabasePath(String dbFileName) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final dbDir = Directory(p.join(docsDir.path, 'ChineseVocabApp'));
  if (!await dbDir.exists()) {
    await dbDir.create(recursive: true);
  }
  return p.join(dbDir.path, dbFileName);
}
