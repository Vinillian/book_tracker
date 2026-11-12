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

  /// Removes the History entries of tasks that were deleted from a tree
  /// (#84). Returns how many entries were removed.
  static int deleteEntriesForTasks(Set<String> nodeIds) {
    if (nodeIds.isEmpty) return 0;
    final keysToDelete = <dynamic>[];
    for (var key in _box.keys) {
      final entry = _box.get(key);
      if (entry != null && nodeIds.contains(entry.nodeId)) {
        keysToDelete.add(key);
      }
    }
    for (var key in keysToDelete) {
      _box.delete(key);
    }
    return keysToDelete.length;
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
    _deleteProgressEntriesByNodeId(node.id);

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

    _deleteProgressEntriesByNodeId(node.id);

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

  /// Adds one 'duration' log. Unlike [recordUniqueToggle] and
  /// [recordUniqueProgress] it never replaces earlier entries of the same
  /// node: several logs per day (and per node) are the point. Returns the
  /// new entry's id, or null when [minutes] is not positive.
  static String? recordDurationLog({
    required String bookId,
    required Node node,
    required int minutes,
    DateTime? targetDate,
  }) {
    if (minutes <= 0) return null;
    final endedAt = targetDate ?? DateTime.now();
    final startedAt = endedAt.subtract(Duration(minutes: minutes));
    final entry = HistoryEntry.forDuration(
      bookId: bookId,
      nodeId: node.id,
      nodeName: node.name,
      minutes: minutes,
      trackingId: node.trackingId,
      date: endedAt,
      startedAt: startedAt,
      endedAt: endedAt,
      recordedAt: DateTime.now(),
    );
    _box.add(entry);
    return entry.id;
  }

  /// All 'duration' logs of one node, newest first.
  static List<HistoryEntry> getDurationEntriesForNode(String nodeId) {
    final list = _box.values
        .where((e) => e.nodeId == nodeId && e.stepType == 'duration')
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Removes a single History entry by its [HistoryEntry.id]. Returns true
  /// if something was removed.
  static bool deleteEntryById(String id) {
    for (var key in _box.keys) {
      final entry = _box.get(key);
      if (entry != null && entry.id == id) {
        _box.delete(key);
        return true;
      }
    }
    return false;
  }

  /// Removes progress entries for one node but never touches duration sessions.
  static void _deleteProgressEntriesByNodeId(String nodeId) {
    final keysToDelete = <dynamic>[];
    for (final key in _box.keys) {
      final entry = _box.get(key);
      if (entry != null &&
          entry.nodeId == nodeId &&
          entry.stepType != 'duration') {
        keysToDelete.add(key);
      }
    }
    for (final key in keysToDelete) {
      _box.delete(key);
    }
  }

  /// Updates one duration session without changing any other session or progress.
  static bool updateDurationLog({
    required String id,
    required int minutes,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    if (minutes <= 0) return false;
    if ((startedAt == null) != (endedAt == null)) return false;
    if (startedAt != null && !endedAt!.isAfter(startedAt)) return false;

    for (final key in _box.keys) {
      final entry = _box.get(key);
      if (entry != null && entry.id == id && entry.stepType == 'duration') {
        entry.minutes = minutes;
        if (startedAt != null && endedAt != null) {
          entry.startedAt = startedAt;
          entry.endedAt = endedAt;
          entry.date = endedAt;
        } else if (entry.endedAt != null) {
          // Keep the end fixed when only the duration is edited.
          entry.startedAt = entry.endedAt!.subtract(Duration(minutes: minutes));
        }
        _box.put(key, entry);
        return true;
      }
    }
    return false;
  }

  /// Most frequent date (without time) among the entries recorded for
  /// [bookId], or null if there are none. Used to recover the date of a day
  /// plan that was renamed before plannedDate existed (#114).
  static DateTime? dominantDateForBook(String bookId) {
    final counts = <DateTime, int>{};
    for (final e in _box.values) {
      if (e.bookId != bookId) continue;
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      counts[d] = (counts[d] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
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