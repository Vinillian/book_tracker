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

  // ===== Удалить все записи для книги/плана =====
  static void deleteEntriesForNode(String bookId) {
    final keysToDelete = <dynamic>[];
    for (var key in _box.keys) {
      final entry = _box.get(key);
      if (entry != null && entry.bookId == bookId) {
        keysToDelete.add(key);
      }
    }
    for (var key in keysToDelete) {
      _box.delete(key);
    }
  }

  // ===== Удалить историю за выбранный день =====
  static Future<void> deleteHistoryForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final keysToDelete = <dynamic>[];
    for (var key in _box.keys) {
      final entry = _box.get(key);
      if (entry != null &&
          entry.date.compareTo(start) >= 0 &&
          entry.date.compareTo(end) < 0) {
        keysToDelete.add(key);
      }
    }
    for (var key in keysToDelete) {
      await _box.delete(key);
    }
  }

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

    _deleteEntryByTrackingId(node.trackingId, startOfDay, endOfDay);

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

    _deleteEntryByTrackingId(node.trackingId, startOfDay, endOfDay);

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

  static void _deleteEntryByTrackingId(String trackingId, DateTime start, DateTime end) {
    dynamic keyToDelete;
    for (var key in _box.keys) {
      final entry = _box.get(key);
      if (entry != null &&
          entry.trackingId == trackingId &&
          entry.date.compareTo(start) >= 0 &&
          entry.date.compareTo(end) < 0) {
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