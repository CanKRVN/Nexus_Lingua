/// Computes consecutive local calendar days with ≥1 review ending today or yesterday.
int computeReviewStreakDays(Iterable<String> ymdDescending) {
  final set = ymdDescending.toSet();
  if (set.isEmpty) return 0;

  String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  final now = DateTime.now();
  var d = DateTime(now.year, now.month, now.day);
  if (!set.contains(ymd(d))) {
    d = d.subtract(const Duration(days: 1));
    if (!set.contains(ymd(d))) {
      return 0;
    }
  }

  var streak = 0;
  while (set.contains(ymd(d))) {
    streak++;
    d = d.subtract(const Duration(days: 1));
  }
  return streak;
}
