import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web: persist SQLite via `sqflite_common_ffi_web` (IndexedDB).
Future<void> configureSqfliteImpl() async {
  databaseFactory = databaseFactoryFfiWeb;
}
