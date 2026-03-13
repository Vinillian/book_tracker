import 'package:hive_flutter/hive_flutter.dart';

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
  String stepType; // 'single' или 'stepByStep'

  @HiveField(6)
  int totalSteps; // общее количество шагов (для stepByStep)

  @HiveField(7)
  int completedSteps; // выполнено шагов (для stepByStep)

  Node({
    required this.name,
    required this.children,
    this.isExpanded = false,
    this.plannedDate,
    this.completed = false,
    this.stepType = 'single',
    this.totalSteps = 1,
    this.completedSteps = 0,
  });

  // Конструктор для листа (по умолчанию single)
  Node.leaf(
    this.name, {
    this.plannedDate,
    this.stepType = 'single',
    this.totalSteps = 1,
    this.completedSteps = 0,
  }) : children = [],
       isExpanded = false,
       completed = false;

  /// Создаёт глубокую копию узла (рекурсивно)
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
    );
  }

  // Общее количество "единиц" прогресса
  int get totalLeaves {
    if (children.isEmpty) {
      return stepType == 'single' ? 1 : totalSteps;
    }
    return children.fold(0, (sum, child) => sum + child.totalLeaves);
  }

  // Количество выполненных "единиц" прогресса
  int get completedLeaves {
    if (children.isEmpty) {
      if (stepType == 'single') return completed ? 1 : 0;
      return completedSteps;
    }
    return children.fold(0, (sum, child) => sum + child.completedLeaves);
  }

  // Переключение для single-задач
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
    );
  }
}
