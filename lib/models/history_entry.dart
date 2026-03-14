import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'history_entry.g.dart';

@HiveType(typeId: 2)
class HistoryEntry {
  @HiveField(0)
  String id;

  @HiveField(1)
  String bookId; // ID корневой книги

  @HiveField(2)
  String nodeId; // ID изменённого узла

  @HiveField(3)
  DateTime date; // дата события (без времени)

  @HiveField(4)
  String nodeName; // имя узла на момент события

  @HiveField(5)
  String stepType; // 'single' или 'stepByStep'

  @HiveField(6)
  bool? completed; // для single

  @HiveField(7)
  int? completedSteps; // для stepByStep

  HistoryEntry({
    String? id,
    required this.bookId,
    required this.nodeId,
    required this.date,
    required this.nodeName,
    required this.stepType,
    this.completed,
    this.completedSteps,
  }) : id = id ?? const Uuid().v4();

  // для удобства создания записи single-задачи
  factory HistoryEntry.forSingle({
    required String bookId,
    required String nodeId,
    required String nodeName,
    required bool completed,
    DateTime? date,
  }) {
    return HistoryEntry(
      bookId: bookId,
      nodeId: nodeId,
      date: date ?? DateTime.now(),
      nodeName: nodeName,
      stepType: 'single',
      completed: completed,
    );
  }

  // для stepByStep
  factory HistoryEntry.forStep({
    required String bookId,
    required String nodeId,
    required String nodeName,
    required int completedSteps,
    DateTime? date,
  }) {
    return HistoryEntry(
      bookId: bookId,
      nodeId: nodeId,
      date: date ?? DateTime.now(),
      nodeName: nodeName,
      stepType: 'stepByStep',
      completedSteps: completedSteps,
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
    );
  }
}
