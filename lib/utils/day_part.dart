import '../models/node.dart';

/// Parts of the day used to group tasks by their start time on the day screen.
/// Derived from `Node.startMinutes`; nothing is stored (#116).
enum DayPart { morning, day, evening, none }

/// Morning: before 12:00, day: 12:00-17:59, evening: from 18:00.
DayPart dayPartOf(int? startMinutes) {
  if (startMinutes == null) return DayPart.none;
  if (startMinutes < 12 * 60) return DayPart.morning;
  if (startMinutes < 18 * 60) return DayPart.day;
  return DayPart.evening;
}

String dayPartLabel(DayPart part) {
  switch (part) {
    case DayPart.morning:
      return 'Утро';
    case DayPart.day:
      return 'День';
    case DayPart.evening:
      return 'Вечер';
    case DayPart.none:
      return 'Без времени';
  }
}

/// `510` -> `08:30`.
String formatMinutes(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// Items sorted by start time; equal times keep their original order
/// (`List.sort` is not guaranteed to be stable, so the index breaks ties).
/// Used for the groups that have a time; items without one sort as 00:00.
List<Node> sortedByStartTime(List<Node> items) {
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final c = (a.$2.startMinutes ?? 0).compareTo(b.$2.startMinutes ?? 0);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}
