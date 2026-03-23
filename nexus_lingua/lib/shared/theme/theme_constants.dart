import 'package:flutter/material.dart';

/// Pinpoint palette — dark cyber shell.
abstract final class NexusPaletteDark {
  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A1A);
  /// Accent cyan — canonical with PRD / `.cursorrules` `accent_cyan` (`#00BCD4`).
  static const Color primary = Color(0xFF00BCD4);
  static const Color success = Color(0xFF00FF94);
  static const Color error = Color(0xFFFF007A);
}

/// Pinpoint palette — light shell.
abstract final class NexusPaletteLight {
  static const Color background = Color(0xFFF0F2F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF00838F);
  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFC2185B);
}
