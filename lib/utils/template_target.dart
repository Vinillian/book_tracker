import '../models/node.dart';

/// Template targets (#117): 'day', 'book' or null = any (old templates).
const String templateTargetDay = 'day';
const String templateTargetBook = 'book';

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
/// fit everything, so old templates keep working.
bool templateMatchesTarget(Node template, String? wanted) {
  if (wanted == null) return true;
  final target = template.templateTarget;
  return target == null || target == wanted;
}

String templateTargetLabel(String? target) {
  switch (target) {
    case templateTargetDay:
      return 'Для дня';
    case templateTargetBook:
      return 'Для книги';
    default:
      return 'Любой';
  }
}
