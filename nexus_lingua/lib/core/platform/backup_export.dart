import 'backup_export_stub.dart'
    if (dart.library.html) 'backup_export_web.dart'
    if (dart.library.io) 'backup_export_io.dart' as impl;

/// Saves JSON backup in a platform-appropriate way (web: download; native: docs dir).
Future<void> exportBackupToFile(String filename, String jsonBody) =>
    impl.exportBackupToFile(filename, jsonBody);
