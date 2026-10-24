import '../models/node.dart';

/// Default start times given to tasks that leave an "Утро" / "День" / "Вечер"
/// (morning / day / evening) folder (#117). Each one falls into the matching
/// part of the day of `dayPartOf` (#116).
const Map<String, int> _dayPartFolderTimes = {
  'утро': 8 * 60,
  'день': 13 * 60,
  'вечер': 19 * 60,
};

/// Whether [node] is a pure container named like a part of the day.
bool isDayPartFolder(Node node) =>
    node.stepType == 'folder' &&
    _dayPartFolderTimes.containsKey(node.name.trim().toLowerCase());

/// Whether the top level of [template] has any such folder.
bool hasDayPartFolders(Node template) => template.children.any(isDayPartFolder);

/// A copy of [template] without its day-part folders (top level only): the
/// tasks of each folder move to the top level in place of the folder, keeping
/// their order, and a task without a start time gets the default time of its
/// folder. Tasks that already have a time keep it. Other tasks and folders are
/// unchanged. [template] itself is not modified and the copy keeps its ids.
Node flattenDayPartFolders(Node template) {
  final copy = template.deepCopy();
  final flat = <Node>[];
  for (final child in copy.children) {
    if (isDayPartFolder(child)) {
      final time = _dayPartFolderTimes[child.name.trim().toLowerCase()]!;
      for (final task in child.children) {
        task.startMinutes ??= time;
        flat.add(task);
      }
    } else {
      flat.add(child);
    }
  }
  copy.children = flat;
  return copy;
}
