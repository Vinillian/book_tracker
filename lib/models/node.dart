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
  }) : id = id ?? const Uuid().v4(),
        trackingId = trackingId ?? const Uuid().v4();

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
      }) : children = [],
        isExpanded = false,
        completed = false,
        id = id ?? const Uuid().v4(),
        trackingId = trackingId ?? const Uuid().v4();

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

  int get _ownTotal => stepType == 'single'
      ? 1
      : (stepType == 'stepByStep' ? totalSteps : 0);

  int get _ownCompleted => stepType == 'single'
      ? (completed ? 1 : 0)
      : (stepType == 'stepByStep' ? completedSteps : 0);

  int get totalLeaves {
    if (excludeFromHistory) return 0;
    if (children.isNotEmpty) {
      final fromChildren =
          children.fold(0, (sum, child) => sum + child.totalLeaves);
      return hasOwnProgress ? fromChildren + _ownTotal : fromChildren;
    }
    if (stepType == 'single') return 1;
    if (stepType == 'stepByStep') return totalSteps;
    return 0;
  }

  int get completedLeaves {
    if (excludeFromHistory) return 0;
    if (children.isNotEmpty) {
      final fromChildren =
          children.fold(0, (sum, child) => sum + child.completedLeaves);
      return hasOwnProgress ? fromChildren + _ownCompleted : fromChildren;
    }
    if (stepType == 'single') return completed ? 1 : 0;
    if (stepType == 'stepByStep') return completedSteps;
    return 0;
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
    );
  }
}