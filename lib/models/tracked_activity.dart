import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'tracked_activity.g.dart';

@HiveType(typeId: 5)
class TrackedActivity {
  @HiveField(0)
  String id;

  /// Legacy Hive field. Retained only to migrate records written by old versions.
  @Deprecated('Use trackingId instead.')
  @HiveField(1)
  String legacyNodeId;

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

  // New field. ID 9 is intentionally unused by the old schema.
  @HiveField(9, defaultValue: '')
  late String trackingId;

  TrackedActivity({
    String? id,
    required String trackingId,
    this.legacyNodeId = '',
    required this.name,
    required this.colorValue,
    required this.stepType,
    this.isActive = true,
    this.isRoutine = false,
    this.order = 0,
    this.timeTrackingEnabled = false,
  }) : id = id ?? const Uuid().v4() {
    this.trackingId = trackingId.isNotEmpty ? trackingId : legacyNodeId;

    // Old heatmap rows used duration as their primary type. Keep their row,
    // but normalize it to the checkbox progress type used by current tasks.
    if (stepType == 'duration') {
      stepType = 'single';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'trackingId': trackingId,
    'name': name,
    'colorValue': colorValue,
    'stepType': stepType,
    'isActive': isActive,
    'isRoutine': isRoutine,
    'order': order,
    'timeTrackingEnabled': timeTrackingEnabled,
  };

  factory TrackedActivity.fromJson(Map<String, dynamic> json) =>
      TrackedActivity(
        id: json['id'],
        // Accept backups created before the field was renamed.
        trackingId: (json['trackingId'] ?? json['nodeId'] ?? '') as String,
        name: json['name'],
        colorValue: json['colorValue'],
        stepType: json['stepType'],
        isActive: json['isActive'] ?? true,
        isRoutine: json['isRoutine'] ?? false,
        order: json['order'] ?? 0,
        timeTrackingEnabled: json['timeTrackingEnabled'] as bool? ?? false,
      );
}
