import 'sqflite_platform_stub.dart'
    if (dart.library.html) 'sqflite_platform_web.dart';

/// Ensures the correct [databaseFactory] before opening SQLite (Web: IndexedDB).
Future<void> configureSqfliteForPlatform() => configureSqfliteImpl();
