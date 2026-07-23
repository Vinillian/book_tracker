import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'tracked_activity.g.dart';

@HiveType(typeId: 5)
class TrackedActivity {
  @HiveField(0)
  String id;

  @HiveField(1)
  String nodeId;

  @HiveField(2)
  String name;

  @HiveField(3)
  int colorValue;

  @HiveField(4)
  String stepType;

  @HiveField(5)
  bool isActive;

  @HiveField(6)
  bool isRoutine;

  @HiveField(7, defaultValue: 0)   // <-- новое поле с дефолтом
  int order;

  TrackedActivity({
    String? id,
    required this.nodeId,
    required this.name,
    required this.colorValue,
    required this.stepType,
    this.isActive = true,
    this.isRoutine = false,
    this.order = 0,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'nodeId': nodeId,
    'name': name,
    'colorValue': colorValue,
    'stepType': stepType,
    'isActive': isActive,
    'isRoutine': isRoutine,
    'order': order,
  };

  factory TrackedActivity.fromJson(Map<String, dynamic> json) => TrackedActivity(
    id: json['id'],
    nodeId: json['nodeId'],
    name: json['name'],
    colorValue: json['colorValue'],
    stepType: json['stepType'],
    isActive: json['isActive'] ?? true,
    isRoutine: json['isRoutine'] ?? false,
    order: json['order'] ?? 0,
  );
}