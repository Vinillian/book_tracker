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

  static void recordUniqueToggle({
    required String bookId,
    required Node node,
    required bool newValue,
    DateTime? targetDate,
  }) {
    final eventDate = targetDate ?? DateTime.now();

    // Один nodeId — одна запись, независимо от того, на какую дату она
    // была записана раньше (защита от рассинхрона дат, а не только от
    // повторных тогглов в один и тот же день).
    _deleteEntryByNodeId(node.id);

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

  static void recordUniqueProgress({
    required String bookId,
    required Node node,
    required int newSteps,
    DateTime? targetDate,
  }) {
    final eventDate = targetDate ?? DateTime.now();

    _deleteEntryByNodeId(node.id);

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

  /// Удаляет любую существующую запись для данного nodeId, независимо от
  /// её даты. Один экземпляр задачи (nodeId) не может законно иметь
  /// больше одной актуальной записи в истории.
  static void _deleteEntryByNodeId(String nodeId) {
    dynamic keyToDelete;
    for (var key in _box.keys) {
      final entry = _box.get(key);
      if (entry != null && entry.nodeId == nodeId) {
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