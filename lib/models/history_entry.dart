import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'history_entry.g.dart';

@HiveType(typeId: 2)
class HistoryEntry {
  @HiveField(0)
  String id;

  @HiveField(1)
  String bookId;

  @HiveField(2)
  String nodeId;        // ID экземпляра задачи (может меняться)

  /// When the event occurred (the selected plan day and event time).
  @HiveField(3)
  DateTime date;

  @HiveField(4)
  String nodeName;

  @HiveField(5)
  String stepType;

  @HiveField(6)
  bool? completed;

  @HiveField(7)
  int? completedSteps;

  @HiveField(8)
  String trackingId;    // постоянный идентификатор для отслеживания

  /// Minutes logged by a 'duration' task (one entry per log, so a task can
  /// have several entries on the same day). Null for other task types.
  @HiveField(9)
  int? minutes;

  /// Actual start of a duration session. Null for legacy entries.
  @HiveField(10)
  DateTime? startedAt;

  /// Actual end of a duration session. Null for legacy entries.
  @HiveField(11)
  DateTime? endedAt;

  /// When this history entry was entered in the app. Null for legacy entries.
  @HiveField(12)
  DateTime? recordedAt;

  /// Progress value before this event (0/1 for checkbox tasks, step count otherwise).
  @HiveField(13)
  int? progressBefore;

  /// Progress value after this event (0/1 for checkbox tasks, step count otherwise).
  @HiveField(14)
  int? progressAfter;

  HistoryEntry({
    String? id,
    required this.bookId,
    required this.nodeId,
    required this.date,
    required this.nodeName,
    required this.stepType,
    this.completed,
    this.completedSteps,
    required this.trackingId,
    this.minutes,
    this.startedAt,
    this.endedAt,
    this.recordedAt,
    this.progressBefore,
    this.progressAfter,
  }) : id = id ?? const Uuid().v4();

  // для single-задачи
  factory HistoryEntry.forSingle({
    required String bookId,
    required String nodeId,
    required String nodeName,
    required bool completed,
    required String trackingId,
    DateTime? date,
    bool? previousCompleted,
  }) {
    return HistoryEntry(
      bookId: bookId,
      nodeId: nodeId,
      date: date ?? DateTime.now(),
      nodeName: nodeName,
      stepType: 'single',
      completed: completed,
      trackingId: trackingId,
      progressBefore: (previousCompleted ?? false) ? 1 : 0,
      progressAfter: completed ? 1 : 0,
      recordedAt: DateTime.now(),
    );
  }

  // для stepByStep
  factory HistoryEntry.forStep({
    required String bookId,
    required String nodeId,
    required String nodeName,
    required int completedSteps,
    required String trackingId,
    DateTime? date,
    int? previousSteps,
  }) {
    return HistoryEntry(
      bookId: bookId,
      nodeId: nodeId,
      date: date ?? DateTime.now(),
      nodeName: nodeName,
      stepType: 'stepByStep',
      completedSteps: completedSteps,
      trackingId: trackingId,
      progressBefore: previousSteps ?? 0,
      progressAfter: completedSteps,
      recordedAt: DateTime.now(),
    );
  }

  // для duration: одна запись на один лог времени
  factory HistoryEntry.forDuration({
    required String bookId,
    required String nodeId,
    required String nodeName,
    required int minutes,
    required String trackingId,
    DateTime? date,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? recordedAt,
  }) {
    final eventEnd = endedAt ?? date ?? DateTime.now();
    return HistoryEntry(
      bookId: bookId,
      nodeId: nodeId,
      date: eventEnd,
      nodeName: nodeName,
      stepType: 'duration',
      minutes: minutes,
      trackingId: trackingId,
      startedAt: startedAt,
      endedAt: endedAt,
      recordedAt: recordedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'nodeId': nodeId,
      'date': date.toIso8601String(),
      'nodeName': nodeName,
      'stepType': stepType,
      'completed': completed,
      'completedSteps': completedSteps,
      'trackingId': trackingId,
      'minutes': minutes,
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'recordedAt': recordedAt?.toIso8601String(),
      'progressBefore': progressBefore,
      'progressAfter': progressAfter,
    };
  }

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'],
      bookId: json['bookId'],
      nodeId: json['nodeId'],
      date: DateTime.parse(json['date']),
      nodeName: json['nodeName'],
      stepType: json['stepType'],
      completed: json['completed'],
      completedSteps: json['completedSteps'],
      trackingId: json['trackingId'] ?? '', // для обратной совместимости
      minutes: json['minutes'] as int?,
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      recordedAt: json['recordedAt'] == null
          ? null
          : DateTime.parse(json['recordedAt'] as String),
      progressBefore: json['progressBefore'] as int?,
      progressAfter: json['progressAfter'] as int?,
    );
  }
}