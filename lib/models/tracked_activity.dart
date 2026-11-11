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

  @HiveField(7, defaultValue: 0)
  int order;

  @HiveField(8, defaultValue: false)
  bool timeTrackingEnabled;

  TrackedActivity({
    String? id,
    required this.nodeId,
    required this.name,
    required this.colorValue,
    required this.stepType,
    this.isActive = true,
    this.isRoutine = false,
    this.order = 0,
    this.timeTrackingEnabled = false,
  }) : id = id ?? const Uuid().v4() {
    // Old heatmap rows used duration as their primary type. Keep their row,
    // but normalize it to the checkbox progress type used by current tasks.
    if (stepType == 'duration') stepType = 'single';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nodeId': nodeId,
    'name': name,
    'colorValue': colorValue,
    'stepType': stepType,
    'isActive': isActive,
    'isRoutine': isRoutine,
    'order': order,
    'timeTrackingEnabled': timeTrackingEnabled,
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
    timeTrackingEnabled: json['timeTrackingEnabled'] as bool? ?? false,
  );
}