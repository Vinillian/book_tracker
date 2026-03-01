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
  bool completed; // true для выполненных листьев

  Node({
    required this.name,
    required this.children,
    this.isExpanded = false,
    this.plannedDate,
    this.completed = false,
  });

  // Конструктор для листа
  Node.leaf(this.name, {this.plannedDate, this.completed = false})
    : children = [],
      isExpanded = false;

  // Рекурсивный подсчёт количества листьев
  int get totalLeaves {
    if (children.isEmpty) return 1;
    return children.fold(0, (sum, child) => sum + child.totalLeaves);
  }

  // Рекурсивный подсчёт выполненных листьев
  int get completedLeaves {
    if (children.isEmpty) return completed ? 1 : 0;
    return children.fold(0, (sum, child) => sum + child.completedLeaves);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'children': children.map((c) => c.toJson()).toList(),
      'plannedDate': plannedDate?.toIso8601String(),
      'completed': completed,
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
    );
  }
}
