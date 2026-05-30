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

  // ========== Уникальная запись с поддержкой удаления ==========

  /// Для одиночных чекбоксов:
  /// - если newValue == true: удаляем старую запись за сегодня и добавляем новую (выполнено)
  /// - если newValue == false: удаляем старую запись за сегодня (если есть)
  static void recordUniqueToggle({
    required String bookId,
    required Node node,
    required bool newValue,
    DateTime? targetDate,
  }) {
    final eventDate = targetDate ?? DateTime.now();
    final startOfDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    dynamic existingKey;
    for (var key in _box.keys) {
      final entry = _box.get(key);
      if (entry != null &&
          entry.nodeId == node.id &&
          entry.date.compareTo(startOfDay) >= 0 &&
          entry.date.compareTo(endOfDay) < 0) {
        existingKey = key;
        break;
      }
    }

    if (existingKey != null) {
      _box.delete(existingKey);
    }

    if (newValue) {
      final newEntry = HistoryEntry.forSingle(
        bookId: bookId,
        nodeId: node.id,
        nodeName: node.name,
        completed: true,
        date: eventDate,
      );
      _box.add(newEntry);
    }
  }

  /// Для пошаговых задач:
  /// - если newSteps > 0: удаляем старую запись за сегодня и добавляем новую с newSteps
  /// - если newSteps == 0: удаляем старую запись за сегодня (если есть)
  static void recordUniqueProgress({
    required String bookId,
    required Node node,
    required int newSteps,
    DateTime? targetDate,
  }) {
    final eventDate = targetDate ?? DateTime.now();
    final startOfDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    dynamic existingKey;
    for (var key in _box.keys) {
      final entry = _box.get(key);
      if (entry != null &&
          entry.nodeId == node.id &&
          entry.date.compareTo(startOfDay) >= 0 &&
          entry.date.compareTo(endOfDay) < 0) {
        existingKey = key;
        break;
      }
    }

    if (existingKey != null) {
      _box.delete(existingKey);
    }

    if (newSteps > 0) {
      final newEntry = HistoryEntry.forStep(
        bookId: bookId,
        nodeId: node.id,
        nodeName: node.name,
        completedSteps: newSteps,
        date: eventDate,
      );
      _box.add(newEntry);
    }
  }

  // ========== Прочие методы ==========

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
