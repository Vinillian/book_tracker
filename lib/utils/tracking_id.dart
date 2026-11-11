import '../models/node.dart';
import '../models/tracked_activity.dart';

/// A snapshot index for resolving task names to their shared tracking IDs.
///
/// Build once when an editor opens instead of traversing every tree on each
/// keystroke. Lookup is O(1) after the initial O(n) index construction.
class TrackingIdIndex {
  final Map<String, String> _activeTracked = {};
  final Map<String, String> _inactiveTracked = {};
  final Map<String, String> _nodes = {};

  TrackingIdIndex({
    required Iterable<TrackedActivity> tracked,
    required Iterable<Node> roots,
  }) {
    for (final activity in tracked) {
      final key = _normalize(activity.name);
      if (key.isEmpty || activity.nodeId.isEmpty) continue;
      if (activity.isActive) {
        _activeTracked.putIfAbsent(key, () => activity.nodeId);
      } else {
        _inactiveTracked.putIfAbsent(key, () => activity.nodeId);
      }
    }
    _indexNodes(roots);
  }

  static String _normalize(String name) => name.trim().toLowerCase();

  void _indexNodes(Iterable<Node> nodes) {
    for (final node in nodes) {
      final key = _normalize(node.name);
      if (node.isTrackableTask &&
          node.trackingId.isNotEmpty &&
          key.isNotEmpty) {
        _nodes.putIfAbsent(key, () => node.trackingId);
      }
      _indexNodes(node.children);
    }
  }

  /// Priority: active tracked activity, inactive tracked activity, first
  /// matching task in depth-first order, then the supplied fallback.
  String resolve(String name, {required String fallback}) {
    final key = _normalize(name);
    if (key.isEmpty) return fallback;
    return _activeTracked[key] ??
        _inactiveTracked[key] ??
        _nodes[key] ??
        fallback;
  }
}

/// One-off convenience wrapper. Editors should retain a [TrackingIdIndex]
/// for repeated name lookups.
String resolveTrackingId(
  String name, {
  required Iterable<TrackedActivity> tracked,
  required Iterable<Node> roots,
  required String fallback,
}) {
  return TrackingIdIndex(
    tracked: tracked,
    roots: roots,
  ).resolve(name, fallback: fallback);
}
