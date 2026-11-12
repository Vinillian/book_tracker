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

  /// Appends a checkbox transition. False transitions are retained as history too.
  static void recordUniqueToggle({
    required String bookId,
    required Node node,
    required bool newValue,
    DateTime? targetDate,
  }) {
    final eventDate = targetDate ?? DateTime.now();
    _box.add(HistoryEntry.forSingle(
      bookId: bookId,
      nodeId: node.id,
      nodeName: node.name,
      completed: newValue,
      previousCompleted: !newValue,
      trackingId: node.trackingId,
      date: eventDate,
    ));
  }

  /// Appends one step-progress transition instead of replacing earlier events.
  static void recordUniqueProgress({
    required String bookId,
    required Node node,
    required int newSteps,
    int? previousSteps,
    DateTime? targetDate,
  }) {
    final eventDate = targetDate ?? DateTime.now();
    _box.add(HistoryEntry.forStep(
      bookId: bookId,
      nodeId: node.id,
      nodeName: node.name,
      completedSteps: newSteps,
      previousSteps: previousSteps ?? 0,
      trackingId: node.trackingId,
      date: eventDate,
    ));
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
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    if (minutes <= 0) return null;
    if ((startedAt == null) != (endedAt == null)) return null;
    final actualEnd = endedAt ?? targetDate ?? DateTime.now();
    final actualStart = startedAt ?? actualEnd.subtract(Duration(minutes: minutes));
    if (!actualEnd.isAfter(actualStart) ||
        actualEnd.difference(actualStart).inMinutes != minutes) {
      return null;
    }
    final entry = HistoryEntry.forDuration(
      bookId: bookId,
      nodeId: node.id,
      nodeName: node.name,
      minutes: minutes,
      trackingId: node.trackingId,
      date: actualEnd,
      startedAt: actualStart,
      endedAt: actualEnd,
      recordedAt: DateTime.now(),
    );
    _box.add(entry);
    return entry.id;
  }

  /// Latest duration session for this node on the selected calendar day.
  static HistoryEntry? getLatestDurationEntryForNodeOnDay(
    String nodeId,
    DateTime day,
  ) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final entries = _box.values.where((entry) =>
        entry.nodeId == nodeId &&
        entry.stepType == 'duration' &&
        entry.date.compareTo(start) >= 0 &&
        entry.date.compareTo(end) < 0).toList();
    if (entries.isEmpty) return null;
    entries.sort((a, b) =>
        (b.endedAt ?? b.date).compareTo(a.endedAt ?? a.date));
    return entries.first;
  }

  /// Suggests a start for quick-add without carrying sessions across days.
  static DateTime suggestDurationStart({
    required String nodeId,
    required DateTime day,
    int? plannedStartMinutes,
    DateTime? now,
  }) {
    final latest = getLatestDurationEntryForNodeOnDay(nodeId, day);
    if (latest != null) return latest.endedAt ?? latest.date;

    final dayStart = DateTime(day.year, day.month, day.day);
    if (plannedStartMinutes != null) {
      return dayStart.add(Duration(minutes: plannedStartMinutes));
    }

    final current = now ?? DateTime.now();
    return DateTime(
      day.year,
      day.month,
      day.day,
      current.hour,
      current.minute,
    );
  }

  /// All 'duration' logs of one node, newest first.
  static List<HistoryEntry> getDurationEntriesForNode(String nodeId) {
    final list = _box.values
        .where((e) => e.nodeId == nodeId && e.stepType == 'duration')
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Corrects the resulting progress value of one historical progress event.
  /// Its event date and previous value stay unchanged; [recordedAt] tracks the correction.
  static bool updateProgressEntry({
    required String id,
    required int newProgress,
  }) {
    if (newProgress < 0) return false;

    for (final key in _box.keys) {
      final entry = _box.get(key);
      if (entry == null || entry.id != id || entry.stepType == 'duration') {
        continue;
      }
      if (entry.stepType == 'single' && newProgress > 1) return false;

      entry.progressBefore ??= 0;
      entry.progressAfter = newProgress;
      if (entry.stepType == 'single') {
        entry.completed = newProgress == 1;
      } else {
        entry.completedSteps = newProgress;
      }
      entry.recordedAt = DateTime.now();
      _box.put(key, entry);
      return true;
    }
    return false;
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