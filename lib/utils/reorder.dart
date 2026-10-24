import '../models/node.dart';

/// New order of [all] after the user dragged an item inside [subset] (#109).
///
/// [subset] is a part of [all] (compared by identity) in its stored order: for
/// example the tasks without a start time on a day screen that groups by time.
/// [oldIndex] and [newIndex] are indices inside [subset] with the convention of
/// Flutter's reorderable lists (`newIndex` is counted before the item is taken
/// out). The subset items are put back into the same slots of [all], so items
/// outside the subset do not move. Neither list is modified.
List<Node> reorderSubset(
  List<Node> all,
  List<Node> subset,
  int oldIndex,
  int newIndex,
) {
  if (oldIndex < 0 || oldIndex >= subset.length) return List<Node>.of(all);
  var target = newIndex;
  if (target > oldIndex) target -= 1;
  target = target.clamp(0, subset.length - 1);

  final moved = List<Node>.of(subset);
  final item = moved.removeAt(oldIndex);
  moved.insert(target, item);

  final members = Set<Node>.identity()..addAll(subset);
  final result = List<Node>.of(all);
  var next = 0;
  for (var i = 0; i < result.length; i++) {
    if (members.contains(result[i])) {
      result[i] = moved[next++];
    }
  }
  return result;
}
