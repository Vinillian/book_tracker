/// Short Russian label for a number of minutes: "45 мин", "2 ч", "1 ч 30 мин".
String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes мин';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h ч' : '$h ч $m мин';
}
