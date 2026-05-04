import 'package:hive_flutter/hive_flutter.dart';
import '../models/history_entry.dart';
import '../models/node.dart';

class HistoryService {
  static Box<HistoryEntry>? _customBox;

  /// Позволяет подменить бокс (например, для тестов).
  static void init(Box<HistoryEntry> box) {
    _customBox = box;
  }

  static Box<HistoryEntry> get _box =>
      _customBox ?? Hive.box<HistoryEntry>('history');

  static void recordToggle({
    required String bookId,
    required Node node,
    required bool newValue,
  }) {
    final entry = HistoryEntry.forSingle(
      bookId: bookId,
      nodeId: node.id,
      nodeName: node.name,
      completed: newValue,
    );
    _box.add(entry);
  }

  static void recordStepChange({
    required String bookId,
    required Node node,
    required int newSteps,
  }) {
    final entry = HistoryEntry.forStep(
      bookId: bookId,
      nodeId: node.id,
      nodeName: node.name,
      completedSteps: newSteps,
    );
    _box.add(entry);
  }

  static List<HistoryEntry> getEntriesForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59);
    return _box.values
        .where((e) => e.date.isAfter(start) && e.date.isBefore(end))
        .toList();
  }

  static Map<DateTime, List<HistoryEntry>> getAllEntriesGroupedByDate() {
    final Map<DateTime, List<HistoryEntry>> grouped = {};
    for (var entry in _box.values) {
      final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
      grouped.putIfAbsent(date, () => []).add(entry);
    }
    return grouped;
  }

  static Future<void> clear() async {
    await _box.clear();
  }
}
