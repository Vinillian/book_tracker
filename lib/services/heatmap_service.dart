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
    final Map<DateTime, Map<String, double>> progressDeltaByDay = {};

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

      double delta;
      if (entry.progressBefore != null && entry.progressAfter != null) {
        delta = (entry.progressAfter! - entry.progressBefore!).toDouble();
      } else if (entry.stepType == 'single' && entry.completed == true) {
        // Legacy records contain only the latest positive snapshot.
        delta = 1;
      } else if (entry.stepType == 'stepByStep' &&
          entry.completedSteps != null) {
        // Legacy records contain only the latest progress snapshot.
        delta = entry.completedSteps!.toDouble();
      } else {
        continue;
      }

      final dayData = progressDeltaByDay.putIfAbsent(
        date,
        () => <String, double>{},
      );
      dayData[entry.trackingId] =
          (dayData[entry.trackingId] ?? 0.0) + delta;
    }

    // Apply the net progress change for each task/day. Reversals offset
    // progress on the day they were recorded but never create positive points.
    for (final dayEntry in progressDeltaByDay.entries) {
      for (final activityEntry in dayEntry.value.entries) {
        final netProgress = activityEntry.value < 0 ? 0.0 : activityEntry.value;
        if (netProgress == 0) continue;
        final dayData = result.putIfAbsent(
          dayEntry.key,
          () => <String, double>{},
        );
        dayData[activityEntry.key] =
            (dayData[activityEntry.key] ?? 0.0) + netProgress;
      }
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
