/// Short Russian label for a number of minutes: "45 мин", "2 ч", "1 ч 30 мин".
/// (Not to be confused with `formatMinutes` in `day_part.dart`, which turns
/// minutes since midnight into a clock time such as "08:30".)
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes мин';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h ч' : '$h ч $m мин';
}

/// Progress of a duration task: "25 мин" without a goal, "25 мин / 1 ч" with one.
String durationProgressLabel(int logged, int? target) {
  if (target == null || target <= 0) return formatDuration(logged);
  return '${formatDuration(logged)} / ${formatDuration(target)}';
}
