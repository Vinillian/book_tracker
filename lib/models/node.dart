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
  bool completed; // для single-задач

  @HiveField(5)
  String stepType; // 'single', 'stepByStep', или 'folder'

  @HiveField(6)
  int totalSteps;

  @HiveField(7)
  int completedSteps;

  @HiveField(8)
  String id;

  @HiveField(9)
  String? category; // 'book', 'planner', 'template'

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
  }) : id = id ?? const Uuid().v4();

  Node.leaf(
      this.name, {
        this.plannedDate,
        this.stepType = 'single',
        this.totalSteps = 1,
        this.completedSteps = 0,
        String? id,
        this.category,
      })  : children = [],
        isExpanded = false,
        completed = false,
        id = id ?? const Uuid().v4();

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
    );
  }

  int get totalLeaves {
    if (children.isNotEmpty) {
      return children.fold(0, (sum, child) => sum + child.totalLeaves);
    }
    if (stepType == 'single') return 1;
    if (stepType == 'stepByStep') return totalSteps;
    return 0;
  }

  int get completedLeaves {
    if (children.isNotEmpty) {
      return children.fold(0, (sum, child) => sum + child.completedLeaves);
    }
    if (stepType == 'single') return completed ? 1 : 0;
    if (stepType == 'stepByStep') return completedSteps;
    return 0;
  }

  void toggle() {
    if (children.isNotEmpty) return;
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
    );
  }
}