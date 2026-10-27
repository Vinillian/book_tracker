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

/// Compares names so that numbers sort as numbers and case is ignored:
/// "Выходной 2" comes before "Выходной 10" (#146).
int compareNamesNaturally(String a, String b) {
  final partsA = _nameParts(a);
  final partsB = _nameParts(b);
  for (var i = 0; i < partsA.length && i < partsB.length; i++) {
    final x = partsA[i];
    final y = partsB[i];
    final int c;
    if (_isDigits(x) && _isDigits(y)) {
      final nx = x.replaceFirst(RegExp(r'^0+(?=.)'), '');
      final ny = y.replaceFirst(RegExp(r'^0+(?=.)'), '');
      c = nx.length != ny.length
          ? nx.length.compareTo(ny.length)
          : nx.compareTo(ny);
    } else {
      c = x.toLowerCase().compareTo(y.toLowerCase());
    }
    if (c != 0) return c;
  }
  return partsA.length.compareTo(partsB.length);
}

List<String> _nameParts(String name) =>
    [for (final m in RegExp(r'\d+|\D+').allMatches(name)) m[0]!];

bool _isDigits(String s) => s.codeUnitAt(0) >= 48 && s.codeUnitAt(0) <= 57;

/// All templates made exactly for a day of [type], ordered by name (numbers
/// as numbers); equal names keep their order in [templates]. The day-off
/// templates are used in this order, one after another (#146).
List<Node> templatesForDayType(Iterable<Node> templates, DayType type) {
  final wanted = templateTargetForDayType(type);
  final matching = <(int, Node)>[];
  var index = 0;
  for (final t in templates) {
    if (t.templateTarget == wanted) matching.add((index, t));
    index++;
  }
  matching.sort((a, b) {
    final c = compareNamesNaturally(a.$2.name, b.$2.name);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final (_, t) in matching) t];
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
