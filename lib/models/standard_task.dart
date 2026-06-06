import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'node.dart';

part 'standard_task.g.dart';

@HiveType(typeId: 4)
class StandardTask {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String stepType; // 'single' or 'stepByStep'

  @HiveField(3)
  int totalSteps;

  @HiveField(4)
  bool excludeFromHistory;

  @HiveField(5)
  int? colorValue; // optional for future heatmap

  StandardTask({
    String? id,
    required this.name,
    required this.stepType,
    this.totalSteps = 1,
    this.excludeFromHistory = false,
    this.colorValue,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'stepType': stepType,
    'totalSteps': totalSteps,
    'excludeFromHistory': excludeFromHistory,
    'colorValue': colorValue,
  };

  factory StandardTask.fromJson(Map<String, dynamic> json) => StandardTask(
    id: json['id'],
    name: json['name'],
    stepType: json['stepType'],
    totalSteps: json['totalSteps'] ?? 1,
    excludeFromHistory: json['excludeFromHistory'] ?? false,
    colorValue: json['colorValue'],
  );

  Node toNode() {
    return Node.leaf(
      name,
      stepType: stepType,
      totalSteps: totalSteps,
      excludeFromHistory: excludeFromHistory,
    );
  }
}