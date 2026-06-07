import 'package:hive_flutter/hive_flutter.dart';
import '../models/history_entry.dart';
import '../models/tracked_activity.dart';

class HeatmapService {
  final Box<HistoryEntry> _historyBox;
  final Box<TrackedActivity> _trackedBox;

  HeatmapService(this._historyBox, this._trackedBox);

  Map<DateTime, Map<String, int>> getIntensityData() {
    final Map<DateTime, Map<String, int>> result = {};

    // Собираем trackingId активных отслеживаемых задач
    final activeTrackingIds = _trackedBox.values
        .where((t) => t.isActive)
        .map((t) => t.nodeId)   // nodeId в TrackedActivity теперь хранит trackingId
        .toSet();

    for (var entry in _historyBox.values) {
      // Сравниваем по trackingId
      if (!activeTrackingIds.contains(entry.trackingId)) continue;

      final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
      result.putIfAbsent(date, () => {});

      int intensity = 0;
      if (entry.stepType == 'single' && entry.completed == true) {
        intensity = 1;
      } else if (entry.stepType == 'stepByStep' && entry.completedSteps != null) {
        intensity = entry.completedSteps!;
      } else {
        continue;
      }

      // Используем trackingId как ключ
      result[date]![entry.trackingId] = (result[date]![entry.trackingId] ?? 0) + intensity;
    }

    return result;
  }

  List<DateTime> getDateRange(DateTime start, DateTime end) {
    final List<DateTime> days = [];
    for (var d = start; d.isBefore(end) || d.isAtSameMomentAs(end); d = d.add(const Duration(days: 1))) {
      days.add(DateTime(d.year, d.month, d.day));
    }
    return days;
  }
}