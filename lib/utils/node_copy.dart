import 'package:uuid/uuid.dart';
import '../models/node.dart';

/// A copy of [node] for reuse (a day from a template, a copied day, tasks added
/// to an existing day): every node gets a new `id` and its progress is reset.
///
/// Logged minutes of `duration` tasks are reset too; their goal is kept.
/// `templateTarget` is cleared (a day or a book made from a template is not a
/// template). `trackingId`, name, steps, start time and subtasks are kept. Keeping
/// `trackingId` is intentional: copies of one habit stay one line in History and
/// the heatmap.
Node copyAndReset(Node node) {
  final copy = node.deepCopy();
  _reset(copy);
  return copy;
}

void _reset(Node node) {
  node.id = const Uuid().v4();
  node.completed = false;
  node.completedSteps = 0;
  node.loggedMinutes = 0;
  node.templateTarget = null;
  for (final child in node.children) {
    _reset(child);
  }
}

/// A new template made from the template [source] (#174): the same tasks with
/// new ids and no progress. [name] and [target] (null = for any day or book)
/// are the new template's own.
Node templateCopy(Node source, {required String name, String? target}) {
  final copy = copyAndReset(source);
  copy.name = name;
  copy.category = 'template';
  copy.templateTarget = target;
  return copy;
}

/// Adds reset copies of the tasks of [source] at the end of the tasks of
/// [target] (loading a base template into another one, #174). Returns how many
/// tasks were added; [source] is not changed.
int appendCopiesOfTasks(Node target, Node source) {
  final copies = [for (final c in source.children) copyAndReset(c)];
  target.children.addAll(copies);
  return copies.length;
}
