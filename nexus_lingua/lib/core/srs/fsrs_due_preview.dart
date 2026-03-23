/// One-line label for “if you tap this rating, next review is…”.
String formatFsrsDuePreview(DateTime now, DateTime due) {
  final diffMs = due.difference(now).inMilliseconds;
  if (diffMs <= 0) {
    return 'Now';
  }
  final days = diffMs / Duration.millisecondsPerDay;
  if (days < 21) {
    final s = days >= 10 ? days.toStringAsFixed(0) : days.toStringAsFixed(1);
    return '+${s}d';
  }
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final m = months[due.month - 1];
  return 'Next: $m ${due.day}';
}
