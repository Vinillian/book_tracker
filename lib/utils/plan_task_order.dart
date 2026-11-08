import '../models/node.dart';
import 'reorder.dart';

/// Display order for the top-level tasks in a day-plan editor.
///
/// Timed tasks are shown first in chronological order. Equal start times keep
/// their stored order. Untimed tasks keep their stored order and remain the
/// only reorderable group. The source list itself is never sorted.
class PlanTaskGroups {
  final List<Node> timed;
  final List<Node> untimed;

  const PlanTaskGroups({required this.timed, required this.untimed});

  List<Node> get displayOrder => [...timed, ...untimed];
}

PlanTaskGroups groupPlanTasks(List<Node> children) {
  final indexedTimed = <(int, Node)>[];
  final untimed = <Node>[];

  for (var i = 0; i < children.length; i++) {
    final child = children[i];
    if (child.startMinutes == null) {
      untimed.add(child);
    } else {
      indexedTimed.add((i, child));
    }
  }

  indexedTimed.sort((a, b) {
    final byTime = a.$2.startMinutes!.compareTo(b.$2.startMinutes!);
    return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
  });

  return PlanTaskGroups(
    timed: [for (final entry in indexedTimed) entry.$2],
    untimed: untimed,
  );
}

/// Reorders only untimed tasks, preserving every timed task's stored slot.
///
/// [oldIndex] and [newIndex] are local to the untimed group and follow
/// ReorderableListView's newIndex convention.
List<Node> reorderUntimedPlanTasks(
  List<Node> all,
  int oldIndex,
  int newIndex,
) {
  final groups = groupPlanTasks(all);
  return reorderSubset(all, groups.untimed, oldIndex, newIndex);
}
