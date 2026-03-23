import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Writes backup next to app documents (Windows/Android/desktop).
Future<void> exportBackupToFile(String filename, String jsonBody) async {
  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, filename);
  final f = File(path);
  await f.writeAsString(jsonBody);
}
