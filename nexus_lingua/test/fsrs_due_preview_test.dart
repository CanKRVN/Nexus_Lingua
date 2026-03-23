import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_lingua/core/srs/fsrs_due_preview.dart';

void main() {
  test('formatFsrsDuePreview uses fractional days under 21d', () {
    final now = DateTime.utc(2025, 1, 1, 12);
    final due = now.add(const Duration(hours: 36));
    expect(formatFsrsDuePreview(now, due), '+1.5d');
  });

  test('formatFsrsDuePreview uses calendar line for long intervals', () {
    final now = DateTime.utc(2025, 1, 1, 12);
    final due = now.add(const Duration(days: 30));
    expect(formatFsrsDuePreview(now, due), 'Next: Jan 31');
  });

  test('formatFsrsDuePreview non-positive delta is Now', () {
    final t = DateTime.utc(2025, 1, 5);
    expect(formatFsrsDuePreview(t, t), 'Now');
  });
}
