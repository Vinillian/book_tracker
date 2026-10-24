import 'package:uuid/uuid.dart';
import '../models/node.dart';

/// A copy of [node] for reuse (a day from a template, a copied day, tasks added
/// to an existing day): every node gets a new `id` and its progress is reset.
///
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
  node.templateTarget = null;
  for (final child in node.children) {
    _reset(child);
  }
}
