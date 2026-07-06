bool get isDesktop => false;

Future<String> getDatabasePath(String dbFileName) async {
  // sqflite_common_ffi_web uses IndexedDB internally and expects just a plain string name or a path that it maps.
  // Returning the filename directly works.
  return dbFileName;
}
