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

  // ========== Старые методы (оставлены для совместимости) ==========

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

  // ========== Новые методы: уникальная запись за день ==========

  /// Удалить старую запись за сегодня для этого узла и добавить новую (для single задач)
  static void recordUniqueToggle({
    required String bookId,
    required Node node,
    required bool newValue,
  }) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Найти существующую запись за сегодня для этого узла
    dynamic existingKey;
    for (var key in _box.keys) {
      final entry = _box.get(key);
      if (entry != null &&
          entry.nodeId == node.id &&
          entry.date.isAfter(startOfDay) &&
          entry.date.isBefore(endOfDay)) {
        existingKey = key;
        break;
      }
    }

    // Удалить старую запись, если есть
    if (existingKey != null) {
      _box.delete(existingKey);
    }

    // Создать новую запись
    final newEntry = HistoryEntry.forSingle(
      bookId: bookId,
      nodeId: node.id,
      nodeName: node.name,
      completed: newValue,
      date: today,
    );
    _box.add(newEntry);
  }

  /// Удалить старую запись за сегодня для этого узла и добавить новую (для stepByStep задач)
  static void recordUniqueProgress({
    required String bookId,
    required Node node,
    required int newSteps,
  }) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Найти существующую запись за сегодня для этого узла
    dynamic existingKey;
    for (var key in _box.keys) {
      final entry = _box.get(key);
      if (entry != null &&
          entry.nodeId == node.id &&
          entry.date.isAfter(startOfDay) &&
          entry.date.isBefore(endOfDay)) {
        existingKey = key;
        break;
      }
    }

    // Удалить старую запись, если есть
    if (existingKey != null) {
      _box.delete(existingKey);
    }

    // Создать новую запись
    final newEntry = HistoryEntry.forStep(
      bookId: bookId,
      nodeId: node.id,
      nodeName: node.name,
      completedSteps: newSteps,
      date: today,
    );
    _box.add(newEntry);
  }

  // ========== Остальные методы (без изменений) ==========

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
