import '../models/node.dart';
import 'work_schedule.dart';

/// Template targets (#117, #145): 'day', 'book', 'work' (a work day), 'off'
/// (a day off) or null = any (old templates).
const String templateTargetDay = 'day';
const String templateTargetBook = 'book';
const String templateTargetWork = 'work';
const String templateTargetOff = 'off';

/// The target needed by a screen that creates a node of [category]
/// ('planner' -> day, 'book' -> book), or null if it does not filter.
String? templateTargetForCategory(String? category) {
  switch (category) {
    case 'planner':
      return templateTargetDay;
    case 'book':
      return templateTargetBook;
    default:
      return null;
  }
}

/// Whether [template] can be offered for [wanted]. Templates without a target
/// fit everything, so old templates keep working. A day screen asks for 'day'
/// and also gets the work-day and day-off templates (#145).
bool templateMatchesTarget(Node template, String? wanted) {
  if (wanted == null) return true;
  final target = template.templateTarget;
  if (target == null || target == wanted) return true;
  return wanted == templateTargetDay &&
      (target == templateTargetWork || target == templateTargetOff);
}

/// The template target of a day of [type].
String templateTargetForDayType(DayType type) =>
    type == DayType.work ? templateTargetWork : templateTargetOff;

/// The template to make a day of [type] from: the first one made exactly for
/// that day type, or null when there is none. Plain day templates and
/// templates without a target are never picked here, so a generator does not
/// guess (#145).
Node? templateForDayType(Iterable<Node> templates, DayType type) {
  final wanted = templateTargetForDayType(type);
  for (final t in templates) {
    if (t.templateTarget == wanted) return t;
  }
  return null;
}

String templateTargetLabel(String? target) {
  switch (target) {
    case templateTargetDay:
      return 'Для дня';
    case templateTargetBook:
      return 'Для книги';
    case templateTargetWork:
      return 'Рабочий день';
    case templateTargetOff:
      return 'Выходной';
    default:
      return 'Любой';
  }
}
