import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'node.g.dart';

@HiveType(typeId: 0)
class Node {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<Node> children;

  @HiveField(2)
  bool isExpanded;

  @HiveField(3)
  DateTime? plannedDate;

  @HiveField(4)
  bool completed;

  @HiveField(5)
  String stepType;

  @HiveField(6)
  int totalSteps;

  @HiveField(7)
  int completedSteps;

  @HiveField(8)
  String id;

  @HiveField(9)
  String? category;

  @HiveField(10)
  bool excludeFromHistory;

  @HiveField(11)
  String trackingId;

  /// Optional start time as minutes after midnight (0-1439). Used only to
  /// group and sort tasks on the day screen; null means "no time" (#116).
  @HiveField(12)
  int? startMinutes;

  /// What a template (`category == 'template'`) is for: 'day', 'book' or null
  /// (any, the value of old templates). Cleared when a template is copied (#117).
  @HiveField(13)
  String? templateTarget;

  /// Optional time goal in minutes for any task; null or 0 means no goal.
  @HiveField(14)
  int? targetMinutes;

  /// Total minutes logged for this task. Individual sessions live in History.
  @HiveField(15, defaultValue: 0)
  int loggedMinutes;

  /// Retained for compatibility with records saved by the first #190 version.
  /// Time tracking is now available to every task with own progress.
  @HiveField(16, defaultValue: false)
  bool timeTrackingEnabled;

  Node({
    required this.name,
    required this.children,
    this.isExpanded = false,
    this.plannedDate,
    this.completed = false,
    this.stepType = 'single',
    this.totalSteps = 1,
    this.completedSteps = 0,
    String? id,
    this.category,
    this.excludeFromHistory = false,
    String? trackingId,
    this.startMinutes,
    this.templateTarget,
    this.targetMinutes,
    this.loggedMinutes = 0,
    this.timeTrackingEnabled = false,
  }) : id = id ?? const Uuid().v4(),
        trackingId = trackingId ?? const Uuid().v4() {
    _normalizeLegacyDuration();
  }

  Node.leaf(
      this.name, {
        this.plannedDate,
        this.stepType = 'single',
        this.totalSteps = 1,
        this.completedSteps = 0,
        String? id,
        this.category,
        this.excludeFromHistory = false,
        String? trackingId,
        this.targetMinutes,
        this.loggedMinutes = 0,
        this.timeTrackingEnabled = false,
      }) : children = [],
        isExpanded = false,
        completed = false,
        id = id ?? const Uuid().v4(),
        trackingId = trackingId ?? const Uuid().v4() {
    _normalizeLegacyDuration();
  }

  /// Convert saved duration-only tasks to checkbox + independent time.
  /// Their old time goal and logged minutes are preserved. If the old task had
  /// already met its time goal, keep that one-time completion as a checked box.
  void _normalizeLegacyDuration() {
    if (stepType != 'duration') return;
    final goal = targetMinutes;
    final wasComplete = goal != null && goal > 0
        ? loggedMinutes >= goal
        : loggedMinutes > 0;
    completed = completed || wasComplete;
    stepType = 'single';
    totalSteps = 1;
    completedSteps = 0;
  }

  Node deepCopy() {
    return Node(
      name: name,
      children: children.map((c) => c.deepCopy()).toList(),
      isExpanded: isExpanded,
      plannedDate: plannedDate,
      completed: completed,
      stepType: stepType,
      totalSteps: totalSteps,
      completedSteps: completedSteps,
      id: id,
      category: category,
      excludeFromHistory: excludeFromHistory,
      trackingId: trackingId,
      startMinutes: startMinutes,
      templateTarget: templateTarget,
      targetMinutes: targetMinutes,
      loggedMinutes: loggedMinutes,
      timeTrackingEnabled: timeTrackingEnabled,
    );
  }

  /// Own progress (checkbox or steps) exists for every non-root task except
  /// pure containers (`folder`). Roots (books, plans, templates) never have it.
  /// Since #111 a task with subtasks keeps it and it counts together with them.
  bool get hasOwnProgress => category == null && stepType != 'folder';

  /// A task whose own progress is recorded in History / the heatmap: a leaf,
  /// or a parent that keeps its own checkbox or steps.
  bool get isTrackableTask =>
      children.isEmpty ? stepType != 'folder' : hasOwnProgress;

  /// Every task with checkbox/step progress can also record time sessions.
  /// The old opt-in flag is intentionally ignored.
  bool get isTimeTrackingEnabled => hasOwnProgress;

  /// True when the separate time goal is reached; this never affects task
  /// completion or plan progress.
  bool get timeGoalReached =>
      (targetMinutes ?? 0) > 0 && loggedMinutes >= targetMinutes!;

  int get _ownTotal {
    if (stepType == 'single') return 1;
    if (stepType == 'stepByStep') return totalSteps;
    return 0;
  }

  int get _ownCompleted {
    if (stepType == 'single') return completed ? 1 : 0;
    if (stepType == 'stepByStep') return completedSteps;
    return 0;
  }

  int get totalLeaves {
    if (excludeFromHistory) return 0;
    if (children.isNotEmpty) {
      final fromChildren =
          children.fold(0, (sum, child) => sum + child.totalLeaves);
      return hasOwnProgress ? fromChildren + _ownTotal : fromChildren;
    }
    return _ownTotal;
  }

  int get completedLeaves {
    if (excludeFromHistory) return 0;
    if (children.isNotEmpty) {
      final fromChildren =
          children.fold(0, (sum, child) => sum + child.completedLeaves);
      return hasOwnProgress ? fromChildren + _ownCompleted : fromChildren;
    }
    return _ownCompleted;
  }

  int get nonRoutineLeafCount {
    if (excludeFromHistory) return 0;
    if (children.isNotEmpty) {
      final fromChildren =
          children.fold(0, (sum, child) => sum + child.nonRoutineLeafCount);
      return hasOwnProgress ? fromChildren + 1 : fromChildren;
    }
    return 1;
  }

  void toggle() {
    if (stepType == 'single') {
      completed = !completed;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'children': children.map((c) => c.toJson()).toList(),
      'plannedDate': plannedDate?.toIso8601String(),
      'completed': completed,
      'stepType': stepType,
      'totalSteps': totalSteps,
      'completedSteps': completedSteps,
      'id': id,
      'category': category,
      'excludeFromHistory': excludeFromHistory,
      'trackingId': trackingId,
      'startMinutes': startMinutes,
      'templateTarget': templateTarget,
      'targetMinutes': targetMinutes,
      'loggedMinutes': loggedMinutes,
      'timeTrackingEnabled': timeTrackingEnabled,
    };
  }

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      name: json['name'],
      children: (json['children'] as List)
          .map((c) => Node.fromJson(c))
          .toList(),
      plannedDate: json['plannedDate'] != null
          ? DateTime.parse(json['plannedDate'])
          : null,
      completed: json['completed'] ?? false,
      stepType: json['stepType'] ?? 'single',
      totalSteps: json['totalSteps'] ?? 1,
      completedSteps: json['completedSteps'] ?? 0,
      id: json['id'],
      category: json['category'],
      excludeFromHistory: json['excludeFromHistory'] ?? false,
      trackingId: json['trackingId'] ?? const Uuid().v4(),
      startMinutes: json['startMinutes'] as int?,
      templateTarget: json['templateTarget'] as String?,
      targetMinutes: json['targetMinutes'] as int?,
      loggedMinutes: json['loggedMinutes'] as int? ?? 0,
      timeTrackingEnabled: json['timeTrackingEnabled'] as bool? ?? false,
    );
  }
}