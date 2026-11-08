import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/history_entry.dart';
import 'package:book_tracker/models/tracked_activity.dart';
import 'package:book_tracker/services/time_analytics_service.dart';

HistoryEntry durationEntry({
  required String trackingId,
  required String name,
  required int minutes,
  required DateTime date,
}) {
  return HistoryEntry.forDuration(
    bookId: 'book',
    nodeId: 'node-$trackingId',
    nodeName: name,
    minutes: minutes,
    trackingId: trackingId,
    date: date,
  );
}

void main() {
  group('TimeAnalyticsService.calculate', () {
    final now = DateTime(2026, 11, 8, 18);

    test('sums persisted duration sessions and ignores completion history', () {
      final entries = [
        durationEntry(
          trackingId: 'study',
          name: 'Учёба',
          minutes: 25,
          date: DateTime(2026, 11, 8, 9),
        ),
        durationEntry(
          trackingId: 'study',
          name: 'Учёба',
          minutes: 35,
          date: DateTime(2026, 11, 8, 12),
        ),
        durationEntry(
          trackingId: 'tai-chi',
          name: 'Тайчи',
          minutes: 40,
          date: DateTime(2026, 11, 7, 8),
        ),
        HistoryEntry.forSingle(
          bookId: 'book',
          nodeId: 'checkbox',
          nodeName: 'Галочка',
          completed: true,
          trackingId: 'checkbox',
          date: DateTime(2026, 11, 8),
        ),
        HistoryEntry.forStep(
          bookId: 'book',
          nodeId: 'steps',
          nodeName: 'Шаги',
          completedSteps: 8,
          trackingId: 'steps',
          date: DateTime(2026, 11, 8),
        ),
      ];

      final result = TimeAnalyticsService.calculate(
        entries: entries,
        selectedTrackingIds: {'study', 'tai-chi', 'checkbox', 'steps'},
        period: TimeAnalyticsPeriod.month,
        now: now,
      );

      expect(result.totalMinutes, 100);
      expect(result.minutesByActivity, {'study': 60, 'tai-chi': 40});
      expect(result.minutesByDay, {
        DateTime(2026, 11, 8): 60,
        DateTime(2026, 11, 7): 40,
      });
      expect(result.daysWithActivity, 2);
      expect(result.daysInPeriod, 8);
      expect(result.averageMinutesPerDay, 12.5);
    });

    test('filters sessions by selected tracking IDs', () {
      final entries = [
        durationEntry(
          trackingId: 'study',
          name: 'Учёба',
          minutes: 90,
          date: DateTime(2026, 11, 8),
        ),
        durationEntry(
          trackingId: 'rest',
          name: 'Отдых',
          minutes: 45,
          date: DateTime(2026, 11, 8),
        ),
      ];

      final result = TimeAnalyticsService.calculate(
        entries: entries,
        selectedTrackingIds: {'rest'},
        period: TimeAnalyticsPeriod.month,
        now: now,
      );

      expect(result.totalMinutes, 45);
      expect(result.minutesByActivity, {'rest': 45});
    });

    test('returns zero metrics when no activities are selected', () {
      final result = TimeAnalyticsService.calculate(
        entries: [
          durationEntry(
            trackingId: 'study',
            name: 'Учёба',
            minutes: 90,
            date: DateTime(2026, 11, 8),
          ),
        ],
        selectedTrackingIds: {},
        period: TimeAnalyticsPeriod.month,
        now: now,
      );

      expect(result.totalMinutes, 0);
      expect(result.minutesByActivity, isEmpty);
      expect(result.minutesByDay, isEmpty);
    });

    test('applies calendar date ranges for each period', () {
      final entries = [
        durationEntry(
          trackingId: 'a',
          name: 'A',
          minutes: 10,
          date: DateTime(2025, 12, 31),
        ),
        durationEntry(
          trackingId: 'a',
          name: 'A',
          minutes: 20,
          date: DateTime(2026, 8, 31),
        ),
        durationEntry(
          trackingId: 'a',
          name: 'A',
          minutes: 30,
          date: DateTime(2026, 9, 1),
        ),
        durationEntry(
          trackingId: 'a',
          name: 'A',
          minutes: 40,
          date: DateTime(2026, 11, 2),
        ),
        durationEntry(
          trackingId: 'a',
          name: 'A',
          minutes: 50,
          date: DateTime(2026, 11, 8),
        ),
      ];

      TimeAnalyticsResult calculate(TimeAnalyticsPeriod period) =>
          TimeAnalyticsService.calculate(
            entries: entries,
            selectedTrackingIds: {'a'},
            period: period,
            now: now,
          );

      final week = calculate(TimeAnalyticsPeriod.week);
      expect(week.startDate, DateTime(2026, 11, 2));
      expect(week.totalMinutes, 90);

      final month = calculate(TimeAnalyticsPeriod.month);
      expect(month.startDate, DateTime(2026, 11, 1));
      expect(month.totalMinutes, 90);

      final threeMonths = calculate(TimeAnalyticsPeriod.threeMonths);
      expect(threeMonths.startDate, DateTime(2026, 9, 1));
      expect(threeMonths.totalMinutes, 120);

      final year = calculate(TimeAnalyticsPeriod.year);
      expect(year.startDate, DateTime(2026, 1, 1));
      expect(year.totalMinutes, 140);

      final allTime = calculate(TimeAnalyticsPeriod.allTime);
      expect(allTime.startDate, DateTime(2025, 12, 31));
      expect(allTime.totalMinutes, 150);
    });

    test('handles empty history without throwing', () {
      final result = TimeAnalyticsService.calculate(
        entries: const [],
        selectedTrackingIds: {'missing'},
        period: TimeAnalyticsPeriod.allTime,
        now: now,
      );

      expect(result.totalMinutes, 0);
      expect(result.daysWithActivity, 0);
      expect(result.daysInPeriod, 1);
      expect(result.isEmpty, isTrue);
    });
  });

  group('TimeAnalyticsService.getAvailableActivities', () {
    test('uses tracked metadata and falls back to historical task names', () {
      final entries = [
        durationEntry(
          trackingId: 'tracked',
          name: 'Старое имя',
          minutes: 20,
          date: DateTime(2026, 11, 8),
        ),
        durationEntry(
          trackingId: 'legacy',
          name: 'Старая активность',
          minutes: 15,
          date: DateTime(2026, 11, 8),
        ),
        HistoryEntry.forSingle(
          bookId: 'book',
          nodeId: 'checkbox',
          nodeName: 'Не временная задача',
          completed: true,
          trackingId: 'checkbox',
        ),
      ];
      final tracked = [
        TrackedActivity(
          nodeId: 'tracked',
          name: 'Новое имя',
          colorValue: 0xFF2196F3,
          stepType: 'single',
          isActive: false,
          order: 2,
        ),
      ];

      final activities = TimeAnalyticsService.getAvailableActivities(
        entries: entries,
        trackedActivities: tracked,
      );

      expect(activities.map((a) => a.trackingId).toSet(), {'tracked', 'legacy'});
      final trackedActivity =
          activities.singleWhere((a) => a.trackingId == 'tracked');
      expect(trackedActivity.name, 'Новое имя');
      expect(trackedActivity.colorValue, 0xFF2196F3);
      final legacyActivity =
          activities.singleWhere((a) => a.trackingId == 'legacy');
      expect(legacyActivity.name, 'Старая активность');
    });

    test('ignores non-positive duration records', () {
      final activities = TimeAnalyticsService.getAvailableActivities(
        entries: [
          durationEntry(
            trackingId: 'zero',
            name: 'Ноль',
            minutes: 0,
            date: DateTime(2026, 11, 8),
          ),
        ],
        trackedActivities: const [],
      );
      expect(activities, isEmpty);
    });
  });
}
