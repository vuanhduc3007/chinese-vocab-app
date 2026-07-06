import 'dart:convert';
import 'dart:html' as html;

Future<String> exportProgressFile(Map<String, dynamic> payload) async {
  final jsonStr = jsonEncode(payload);
  final blob = html.Blob([jsonStr], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', 'progress_backup_${DateTime.now().millisecondsSinceEpoch}.json')
    ..click();
  html.Url.revokeObjectUrl(url);
  return 'Thư mục Downloads của trình duyệt';
}

Future<String> backupDatabaseFileIo() async {
  throw Exception('Tính năng copy file database (SQLite) không khả dụng trên trình duyệt Web. Xin hãy dùng tính năng Export Progress thay thế.');
}
