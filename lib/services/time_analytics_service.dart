import '../models/history_entry.dart';
import '../models/tracked_activity.dart';

/// Reporting windows for time-only analytics.
///
/// The ranges are calendar based: week starts on Monday, month starts on the
/// first day of the current month, three months covers the current and two
/// preceding calendar months, and year starts on January 1.
enum TimeAnalyticsPeriod {
  week,
  month,
  threeMonths,
  year,
  allTime,
}

extension TimeAnalyticsPeriodLabel on TimeAnalyticsPeriod {
  String get label {
    switch (this) {
      case TimeAnalyticsPeriod.week:
        return 'Неделя';
      case TimeAnalyticsPeriod.month:
        return 'Месяц';
      case TimeAnalyticsPeriod.threeMonths:
        return '3 месяца';
      case TimeAnalyticsPeriod.year:
        return 'Год';
      case TimeAnalyticsPeriod.allTime:
        return 'Всё время';
    }
  }
}

/// Presentation metadata for a task that has at least one recorded time log.
///
/// This is deliberately a projection rather than a new persisted model. It
/// leaves room for optional category metadata to be added later without
/// coupling the analytics calculations to Hive or the UI.
class TimeAnalyticsActivity {
  final String trackingId;
  final String name;
  final int colorValue;
  final int order;

  const TimeAnalyticsActivity({
    required this.trackingId,
    required this.name,
    required this.colorValue,
    required this.order,
  });
}

class TimeAnalyticsResult {
  final DateTime startDate;
  final DateTime endDate;
  final int daysInPeriod;
  final int totalMinutes;
  final int daysWithActivity;
  final Map<String, int> minutesByActivity;
  final Map<DateTime, int> minutesByDay;

  const TimeAnalyticsResult({
    required this.startDate,
    required this.endDate,
    required this.daysInPeriod,
    required this.totalMinutes,
    required this.daysWithActivity,
    required this.minutesByActivity,
    required this.minutesByDay,
  });

  double get averageMinutesPerDay =>
      daysInPeriod == 0 ? 0 : totalMinutes / daysInPeriod;

  bool get isEmpty => totalMinutes == 0;
}

class TimeAnalyticsService {
  static const int _fallbackColor = 0xFF607D8B;

  /// Returns tasks represented by persisted positive-duration sessions.
  ///
  /// Historical sessions remain available even if a tracked activity is now
  /// inactive. If an old session has no matching tracked-activity record, its
  /// stored task name is used as a fallback.
  static List<TimeAnalyticsActivity> getAvailableActivities({
    required Iterable<HistoryEntry> entries,
    required Iterable<TrackedActivity> trackedActivities,
  }) {
    final trackedById = <String, TrackedActivity>{};
    for (final activity in trackedActivities) {
      trackedById.putIfAbsent(activity.nodeId, () => activity);
    }

    final namesById = <String, String>{};
    for (final entry in entries) {
      if (entry.stepType != 'duration' ||
          (entry.minutes ?? 0) <= 0 ||
          entry.trackingId.isEmpty) {
        continue;
      }
      namesById.putIfAbsent(entry.trackingId, () => entry.nodeName);
    }

    final activities = namesById.entries.map((entry) {
      final tracked = trackedById[entry.key];
      return TimeAnalyticsActivity(
        trackingId: entry.key,
        name: tracked?.name.isNotEmpty == true ? tracked!.name : entry.value,
        colorValue: tracked?.colorValue ?? _fallbackColor,
        order: tracked?.order ?? 0,
      );
    }).toList();

    activities.sort((a, b) {
      if (a.order != b.order) return a.order.compareTo(b.order);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return activities;
  }

  static DateTime periodStart(
    TimeAnalyticsPeriod period,
    DateTime now, {
    DateTime? firstSessionDate,
  }) {
    final today = _day(now);
    switch (period) {
      case TimeAnalyticsPeriod.week:
        return today.subtract(Duration(days: today.weekday - DateTime.monday));
      case TimeAnalyticsPeriod.month:
        return DateTime(today.year, today.month);
      case TimeAnalyticsPeriod.threeMonths:
        return DateTime(today.year, today.month - 2);
      case TimeAnalyticsPeriod.year:
        return DateTime(today.year);
      case TimeAnalyticsPeriod.allTime:
        return firstSessionDate == null ? today : _day(firstSessionDate);
    }
  }

  static TimeAnalyticsResult calculate({
    required Iterable<HistoryEntry> entries,
    required Set<String> selectedTrackingIds,
    required TimeAnalyticsPeriod period,
    DateTime? now,
  }) {
    final currentDay = _day(now ?? DateTime.now());
    final durationEntries = entries
        .where((entry) =>
            entry.stepType == 'duration' && (entry.minutes ?? 0) > 0)
        .toList();

    final selectedDurationEntries = durationEntries
        .where((entry) => selectedTrackingIds.contains(entry.trackingId))
        .toList();

    DateTime? firstSessionDate;
    for (final entry in selectedDurationEntries) {
      final day = _day(entry.date);
      if (firstSessionDate == null || day.isBefore(firstSessionDate)) {
        firstSessionDate = day;
      }
    }

    final start = periodStart(
      period,
      currentDay,
      firstSessionDate: firstSessionDate,
    );
    final end = currentDay;
    final daysInPeriod = end.isBefore(start) ? 0 : end.difference(start).inDays + 1;

    final byActivity = <String, int>{};
    final byDay = <DateTime, int>{};

    if (selectedDurationEntries.isNotEmpty && daysInPeriod > 0) {
      for (final entry in selectedDurationEntries) {
        final day = _day(entry.date);
        if (day.isBefore(start) || day.isAfter(end)) continue;

        final minutes = entry.minutes!;
        byActivity[entry.trackingId] =
            (byActivity[entry.trackingId] ?? 0) + minutes;
        byDay[day] = (byDay[day] ?? 0) + minutes;
      }
    }

    final total = byActivity.values.fold<int>(0, (sum, value) => sum + value);
    return TimeAnalyticsResult(
      startDate: start,
      endDate: end,
      daysInPeriod: daysInPeriod,
      totalMinutes: total,
      daysWithActivity: byDay.length,
      minutesByActivity: Map.unmodifiable(byActivity),
      minutesByDay: Map.unmodifiable(byDay),
    );
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
