import '../models/node.dart';
import '../models/standard_task.dart';
import '../models/tracked_activity.dart';

/// A task that can be put under tracking on the heatmap (#173).
class TrackingChoice {
  final String name;
  final String stepType;
  final int totalSteps;
  final String trackingId;
  final bool timeTrackingEnabled;

  const TrackingChoice({
    required this.name,
    required this.stepType,
    required this.totalSteps,
    required this.trackingId,
    this.timeTrackingEnabled = false,
  });

  /// The primary completion mode; time sessions are available separately.
  String get description => stepType == 'stepByStep'
      ? 'Пошаговая ($totalSteps шагов)'
      : 'Одиночный чекбокс';

  /// A throw-away task carrying the primary progress type and tracking id;
  /// independent time sessions are available for all task progress types.
  Node toNode() => Node.leaf(
    name,
    stepType: stepType,
    totalSteps: totalSteps,
    trackingId: trackingId,
    timeTrackingEnabled: timeTrackingEnabled,
  );
}

/// The tasks offered for tracking: every standard task first, with its own
/// definition (so an edited standard task shows its new type and steps), then
/// the tasks found in plans ([planLeaves]) whose tracking id no standard task
/// has. Tasks excluded from history are left out. Ordered by name, case
/// ignored.
List<TrackingChoice> trackingChoices({
  required Iterable<StandardTask> standardTasks,
  required Iterable<Node> planLeaves,
}) {
  final byTrackingId = <String, TrackingChoice>{};
  for (final task in standardTasks) {
    if (task.excludeFromHistory) continue;
    byTrackingId.putIfAbsent(
      task.trackingId,
      () => TrackingChoice(
        name: task.name,
        stepType: task.stepType,
        totalSteps: task.totalSteps,
        trackingId: task.trackingId,
        timeTrackingEnabled: task.timeTrackingEnabled,
      ),
    );
  }
  for (final node in planLeaves) {
    if (node.excludeFromHistory) continue;
    byTrackingId.putIfAbsent(
      node.trackingId,
      () => TrackingChoice(
        name: node.name,
        stepType: node.stepType,
        totalSteps: node.totalSteps,
        trackingId: node.trackingId,
        timeTrackingEnabled: node.timeTrackingEnabled,
      ),
    );
  }
  final result = byTrackingId.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return result;
}

/// The tracked [activity] with the name and type of the edited standard [task],
/// or null when nothing changes: the activity follows another task, or already
/// says the same. [previousTrackingId] is the tracking id the task had before
/// the edit (it can change when the task is renamed).
TrackedActivity? trackedActivityFollowing(
  TrackedActivity activity,
  StandardTask task, {
  required String previousTrackingId,
  bool hasDurationHistory = false,
}) {
  if (activity.trackingId != previousTrackingId &&
      activity.trackingId != task.trackingId) {
    return null;
  }
  final nextTimeTrackingEnabled =
      activity.timeTrackingEnabled ||
      task.timeTrackingEnabled ||
      hasDurationHistory;
  if (activity.name == task.name &&
      activity.stepType == task.stepType &&
      activity.timeTrackingEnabled == nextTimeTrackingEnabled) {
    return null;
  }
  return TrackedActivity(
    id: activity.id,
    trackingId: activity.trackingId,
    name: task.name,
    colorValue: activity.colorValue,
    stepType: task.stepType,
    isActive: activity.isActive,
    isRoutine: activity.isRoutine,
    order: activity.order,
    timeTrackingEnabled: nextTimeTrackingEnabled,
  );
}
