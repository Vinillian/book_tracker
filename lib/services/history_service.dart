import 'package:hive_flutter/hive_flutter.dart';
import '../models/history_entry.dart';
import '../models/node.dart';

class HistoryService {
  static Box<HistoryEntry>? _customBox;

  static void init(Box<HistoryEntry> box) {
    _customBox = box;
  }

  static Box<HistoryEntry> get _box =>
      _customBox ?? Hive.box<HistoryEntry>('history');

  // Для одиночных чекбоксов
  static void recordUniqueToggle({
    required String bookId,
    required Node node,
    required bool newValue,
    DateTime? targetDate,
  }) {
    final eventDate = targetDate ?? DateTime.now();
    final startOfDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Удаляем существующую запись для этого конкретного экземпляра (nodeId)
    _deleteEntryByNodeId(node.id, startOfDay, endOfDay);

    // Если новое значение true – создаём новую запись
    if (newValue) {
      final newEntry = HistoryEntry.forSingle(
        bookId: bookId,
        nodeId: node.id,
        nodeName: node.name,
        completed: true,
        trackingId: node.trackingId,
        date: eventDate,
      );
      _box.add(newEntry);
    }
  }

  // Для пошаговых задач
  static void recordUniqueProgress({
    required String bookId,
    required Node node,
    required int newSteps,
    DateTime? targetDate,
  }) {
    final eventDate = targetDate ?? DateTime.now();
    final startOfDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Удаляем существующую запись для этого конкретного экземпляра (nodeId)
    _deleteEntryByNodeId(node.id, startOfDay, endOfDay);

    // Если прогресс > 0 – создаём новую запись
    if (newSteps > 0) {
      final newEntry = HistoryEntry.forStep(
        bookId: bookId,
        nodeId: node.id,
        nodeName: node.name,
        completedSteps: newSteps,
        trackingId: node.trackingId,
        date: eventDate,
      );
      _box.add(newEntry);
    }
  }

  // Вспомогательный метод для удаления записи по nodeId
  static void _deleteEntryByNodeId(String nodeId, DateTime start, DateTime end) {
    dynamic keyToDelete;
    for (var key in _box.keys) {
      final entry = _box.get(key);
      if (entry != null &&
          entry.nodeId == nodeId &&
          entry.date.isAfter(start) &&
          entry.date.isBefore(end)) {
        keyToDelete = key;
        break;
      }
    }
    if (keyToDelete != null) {
      _box.delete(keyToDelete);
    }
  }

  static List<HistoryEntry> getEntriesForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _box.values
        .where((e) => e.date.compareTo(start) >= 0 && e.date.compareTo(end) < 0)
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