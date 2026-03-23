import 'package:flutter/services.dart';

/// Fallback: copy to clipboard (e.g. WASM / unknown host).
Future<void> exportBackupToFile(String filename, String jsonBody) async {
  await Clipboard.setData(ClipboardData(text: jsonBody));
}
