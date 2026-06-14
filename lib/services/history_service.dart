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

    dynamic existingKey;
    for (var key in _box.keys) {
      final entry = _box.get(key);
      if (entry != null &&
          entry.trackingId == node.trackingId &&   // сравниваем по trackingId
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

    dynamic existingKey;
    for (var key in _box.keys) {
      final entry = _box.get(key);
      if (entry != null &&
          entry.trackingId == node.trackingId &&
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
        trackingId: node.trackingId,
        date: eventDate,
      );
      _box.add(newEntry);
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