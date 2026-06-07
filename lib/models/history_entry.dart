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
  }) : id = id ?? const Uuid().v4();

  // для single-задачи
  factory HistoryEntry.forSingle({
    required String bookId,
    required String nodeId,
    required String nodeName,
    required bool completed,
    required String trackingId,
    DateTime? date,
  }) {
    return HistoryEntry(
      bookId: bookId,
      nodeId: nodeId,
      date: date ?? DateTime.now(),
      nodeName: nodeName,
      stepType: 'single',
      completed: completed,
      trackingId: trackingId,
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
  }) {
    return HistoryEntry(
      bookId: bookId,
      nodeId: nodeId,
      date: date ?? DateTime.now(),
      nodeName: nodeName,
      stepType: 'stepByStep',
      completedSteps: completedSteps,
      trackingId: trackingId,
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
    );
  }
}