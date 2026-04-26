import 'package:hive_flutter/hive_flutter.dart';
import '../models/history_entry.dart';
import '../models/node.dart';

class HistoryService {
  static final Box<HistoryEntry> _historyBox = Hive.box<HistoryEntry>(
    'history',
  );

  /// Записать изменение single-задачи (чекбокс)
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
    _historyBox.add(entry);
  }

  /// Записать изменение stepByStep (количество выполненных шагов)
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
    _historyBox.add(entry);
  }

  /// Получить все записи за определённый день (дата без времени)
  static List<HistoryEntry> getEntriesForDay(DateTime day) {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);

    return _historyBox.values.where((entry) {
      return entry.date.isAfter(startOfDay) && entry.date.isBefore(endOfDay);
    }).toList();
  }

  /// Получить все записи, сгруппированные по датам
  static Map<DateTime, List<HistoryEntry>> getAllEntriesGroupedByDate() {
    final Map<DateTime, List<HistoryEntry>> grouped = {};
    for (var entry in _historyBox.values) {
      final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
      // putIfAbsent гарантирует наличие списка и не требует !
      grouped.putIfAbsent(date, () => []).add(entry);
    }
    return grouped;
  }

  /// Очистить историю (опционально)
  static Future<void> clearHistory() async {
    await _historyBox.clear();
  }
}
