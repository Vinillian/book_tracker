import '../models/node.dart';
import '../models/tracked_activity.dart';

/// Picks the `trackingId` for a task that is being created with [name]
/// (#149). A habit keeps one line in History and in the heatmap only if all
/// its tasks share one `trackingId`, so the order is:
///
/// 1. an already tracked activity with this name (an active one wins),
/// 2. an existing task with this name,
/// 3. [fallback] (a brand new habit).
///
/// Names are compared ignoring case and surrounding spaces.
String resolveTrackingId(
  String name, {
  required Iterable<TrackedActivity> tracked,
  required Iterable<Node> roots,
  required String fallback,
}) {
  final key = name.trim().toLowerCase();
  if (key.isEmpty) return fallback;

  TrackedActivity? inactive;
  for (final a in tracked) {
    if (a.name.trim().toLowerCase() != key || a.nodeId.isEmpty) continue;
    if (a.isActive) return a.nodeId;
    inactive ??= a;
  }
  if (inactive != null) return inactive.nodeId;

  String? fromNodes(Iterable<Node> nodes) {
    for (final node in nodes) {
      if (node.isTrackableTask &&
          node.trackingId.isNotEmpty &&
          node.name.trim().toLowerCase() == key) {
        return node.trackingId;
      }
      final inChildren = fromNodes(node.children);
      if (inChildren != null) return inChildren;
    }
    return null;
  }

  return fromNodes(roots) ?? fallback;
}
