import 'package:hive_flutter/hive_flutter.dart';
import '../models/history_entry.dart';
import '../models/tracked_activity.dart';

class HeatmapService {
  final Box<HistoryEntry> _historyBox;
  final Box<TrackedActivity> _trackedBox;

  HeatmapService(this._historyBox, this._trackedBox);

  Map<DateTime, Map<String, double>> getIntensityData() {
    final Map<DateTime, Map<String, double>> result = {};
    final Map<DateTime, Map<String, int>> durationMinutesByDay = {};

    // Собираем trackingId активных отслеживаемых задач.
    final activeTrackingIds = _trackedBox.values
        .where((activity) => activity.isActive)
        .map((activity) => activity.nodeId)
        .toSet();

    for (final entry in _historyBox.values) {
      if (!activeTrackingIds.contains(entry.trackingId)) continue;

      final date = DateTime(entry.date.year, entry.date.month, entry.date.day);

      if (entry.stepType == 'duration') {
        final minutes = entry.minutes ?? 0;
        if (minutes <= 0) continue;

        // Сначала суммируем все сессии за день и trackingId.
        final dayMinutes =
            durationMinutesByDay.putIfAbsent(date, () => <String, int>{});
        dayMinutes[entry.trackingId] =
            (dayMinutes[entry.trackingId] ?? 0) + minutes;
        continue;
      }

      double intensity;
      if (entry.stepType == 'single' && entry.completed == true) {
        intensity = 1;
      } else if (entry.stepType == 'stepByStep' &&
          entry.completedSteps != null) {
        intensity = entry.completedSteps!.toDouble();
      } else {
        continue;
      }

      final dayData = result.putIfAbsent(date, () => <String, double>{});
      dayData[entry.trackingId] =
          (dayData[entry.trackingId] ?? 0.0) + intensity;
    }

    // 20 minutes = 1 point. Keep partial points instead of rounding.
    for (final dayEntry in durationMinutesByDay.entries) {
      final dayData =
          result.putIfAbsent(dayEntry.key, () => <String, double>{});
      for (final activityEntry in dayEntry.value.entries) {
        final points = activityEntry.value / 20;
        dayData[activityEntry.key] =
            (dayData[activityEntry.key] ?? 0.0) + points;
      }
    }

    return result;
  }

  static List<DateTime> getDateRange(DateTime start, DateTime end) {
    final List<DateTime> days = [];
    for (var d = start;
        d.isBefore(end) || d.isAtSameMomentAs(end);
        d = d.add(const Duration(days: 1))) {
      days.add(DateTime(d.year, d.month, d.day));
    }
    return days;
  }
}
