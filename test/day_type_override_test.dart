import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/file_transfer.dart';
import 'package:book_tracker/utils/plan_generator.dart';
import 'package:book_tracker/utils/template_target.dart';
import 'package:book_tracker/utils/work_schedule.dart';

DateTime d(int day) => DateTime(2026, 10, day);

// 2 on / 2 off, 23.10.2026 is the first day off:
//   off: 23 24 | work: 25 26 | off: 27 28 | work: 29 30 | off: 31 01.11 ...
WorkSchedule base() => WorkSchedule(
      workDays: 2,
      offDays: 2,
      anchor: d(23),
    );

WorkSchedule with_(Map<DateTime, DayType> overrides) => WorkSchedule(
      workDays: 2,
      offDays: 2,
      anchor: d(23),
      overrides: overrides,
    );

Node template(String name, String target) => Node(
      name: name,
      children: [Node.leaf('a')],
      category: 'template',
      templateTarget: target,
    );

void main() {
  group('dayTypeOf with overrides', () {
    test('a work day made a day off, neighbours keep the rule', () {
      final s = with_({d(25): DayType.off});
      expect(s.dayTypeOf(d(25)), DayType.off);
      expect(s.baseDayTypeOf(d(25)), DayType.work);
      expect(s.isOverridden(d(25)), isTrue);
      expect(s.dayTypeOf(d(24)), DayType.off);
      expect(s.dayTypeOf(d(26)), DayType.work);
      expect(s.isOverridden(d(26)), isFalse);
    });

    test('a day off made a work day', () {
      final s = with_({d(27): DayType.work});
      expect(s.dayTypeOf(d(27)), DayType.work);
      expect(s.baseDayTypeOf(d(27)), DayType.off);
      expect(s.dayTypeOf(d(28)), DayType.off);
    });

    test('the time of day does not matter', () {
      final s = with_({d(25): DayType.off});
      expect(s.dayTypeOf(DateTime(2026, 10, 25, 18, 30)), DayType.off);
      expect(s.isOverridden(DateTime(2026, 10, 25, 3)), isTrue);
    });

    test('works before the anchor and across a year end', () {
      for (final date in [
        DateTime(2026, 10, 1),
        DateTime(2025, 12, 31),
        DateTime(2027, 1, 1),
        DateTime(2028, 2, 29),
      ]) {
        final rule = base().baseDayTypeOf(date);
        final other = rule == DayType.work ? DayType.off : DayType.work;
        final s = with_({date: other});
        expect(s.dayTypeOf(date), other, reason: '$date');
        expect(s.baseDayTypeOf(date), rule, reason: '$date');
      }
    });
  });

  group('withDayType / copyWith', () {
    test('sets a day and leaves the original alone', () {
      final s = base();
      final changed = s.withDayType(d(25), DayType.off);
      expect(changed.dayTypeOf(d(25)), DayType.off);
      expect(s.dayTypeOf(d(25)), DayType.work);
      expect(s.overrides, isEmpty);
    });

    test('an override equal to the rule is not stored', () {
      final s = base().withDayType(d(25), DayType.work);
      expect(s.overrides, isEmpty);
      expect(s.isOverridden(d(25)), isFalse);
    });

    test('null brings the rule back, other days stay', () {
      final s = with_({d(25): DayType.off, d(27): DayType.work})
          .withDayType(d(25), null);
      expect(s.overrides, {d(27): DayType.work});
    });

    test('changing the same day again replaces the override', () {
      final s = base()
          .withDayType(d(25), DayType.off)
          .withDayType(d(25), DayType.work);
      expect(s.overrides, isEmpty);
    });

    test('the overrides cannot be changed in place, keys lose the time', () {
      final s = WorkSchedule(
        workDays: 2,
        offDays: 2,
        anchor: d(23),
        overrides: {DateTime(2026, 10, 25, 14, 45): DayType.off},
      );
      expect(s.overrides.keys.single, d(25));
      expect(() => s.overrides[d(26)] = DayType.off, throwsUnsupportedError);
    });

    test('copyWith keeps the overrides when the rule changes', () {
      final s = with_({d(25): DayType.off}).copyWith(workDays: 3);
      expect(s.workDays, 3);
      expect(s.overrides, {d(25): DayType.off});
    });
  });

  group('offDayOrdinalOf with overrides', () {
    test('without overrides it is the same as before', () {
      final s = base();
      expect(
        [for (final day in [23, 24, 25, 26, 27, 28, 31]) s.offDayOrdinalOf(d(day))],
        [0, 1, null, null, 2, 3, 4],
      );
    });

    test('a work day made a day off takes its place in the sequence', () {
      final s = with_({d(25): DayType.off}); // a holiday
      expect(
        [for (final day in [23, 24, 25, 26, 27, 28, 31]) s.offDayOrdinalOf(d(day))],
        [0, 1, 2, null, 3, 4, 5],
      );
    });

    test('a day off made a work day drops out of the sequence', () {
      final s = with_({d(27): DayType.work});
      expect(
        [for (final day in [23, 24, 27, 28, 31]) s.offDayOrdinalOf(d(day))],
        [0, 1, null, 2, 3],
      );
    });

    test('a swapped shift keeps everything after it where it was', () {
      final s = with_({d(25): DayType.off, d(27): DayType.work});
      expect(
        [for (final day in [23, 24, 25, 27, 28, 31]) s.offDayOrdinalOf(d(day))],
        [0, 1, 2, null, 3, 4],
      );
    });

    test('an override later than the day does not change it', () {
      final s = with_({d(29): DayType.off});
      expect(s.offDayOrdinalOf(d(27)), 2);
      expect(s.offDayOrdinalOf(d(28)), 3);
      expect(s.offDayOrdinalOf(d(29)), 4);
      expect(s.offDayOrdinalOf(d(31)), 5); // after 23 24 27 28 29
    });

    test('an override equal to the rule changes nothing', () {
      final s = with_({d(23): DayType.off, d(25): DayType.work});
      expect(s.offDayOrdinalOf(d(27)), 2);
    });

    test('overrides before the anchor count backwards', () {
      // 19.10 and 20.10 are days off by the rule; 21.10 is made a day off.
      final s = with_({d(21): DayType.off});
      expect(s.offDayOrdinalOf(d(23)), 0);
      expect(s.offDayOrdinalOf(d(21)), -1);
      expect(s.offDayOrdinalOf(d(20)), -2);
      expect(s.offDayOrdinalOf(d(19)), -3);
      expect(s.offDayOrdinalOf(d(22)), isNull);
    });

    test('with the anchor on a work block', () {
      final s = WorkSchedule(
        workDays: 2,
        offDays: 2,
        anchor: d(23),
        anchorIsWork: true,
        overrides: {d(23): DayType.off}, // 23, 24 work by the rule
      );
      // days off now: 23 (by hand), 25, 26, 29, 30
      expect(
        [for (final day in [23, 24, 25, 26, 29, 30]) s.offDayOrdinalOf(d(day))],
        [0, null, 1, 2, 3, 4],
      );
    });

    test('is non-null exactly on days off and grows by one each time', () {
      final s = WorkSchedule(
        workDays: 3,
        offDays: 2,
        anchor: d(23),
        anchorIsWork: true,
        overrides: {
          d(10): DayType.work,
          d(15): DayType.off,
          d(24): DayType.off,
          d(26): DayType.work,
          d(30): DayType.off,
          DateTime(2026, 11, 9): DayType.work,
        },
      );
      int? previous;
      for (var i = -30; i < 60; i++) {
        final date = DateTime(2026, 10, 23 + i);
        final ordinal = s.offDayOrdinalOf(date);
        expect(ordinal != null, s.dayTypeOf(date) == DayType.off, reason: '$date');
        if (ordinal != null) {
          if (previous != null) expect(ordinal, previous + 1, reason: '$date');
          previous = ordinal;
        }
      }
    });
  });

  group('saving', () {
    test('overrides survive encode and parse, in date order', () {
      final s = with_({d(27): DayType.work, d(25): DayType.off});
      final json = jsonDecode(s.encode()) as Map<String, dynamic>;
      expect(json['overrides'], {'2026-10-25': 'off', '2026-10-27': 'work'});
      expect((json['overrides'] as Map).keys.toList(),
          ['2026-10-25', '2026-10-27']);

      final back = WorkSchedule.tryParse(s.encode())!;
      expect(back.overrides, {d(25): DayType.off, d(27): DayType.work});
      expect(back.workDays, 2);
      expect(back.dayTypeOf(d(25)), DayType.off);
    });

    test('a schedule without overrides writes no key', () {
      expect(base().toJson().containsKey('overrides'), isFalse);
    });

    test('a schedule saved before the overrides existed still loads', () {
      final back = WorkSchedule.tryParse(
        '{"workDays":2,"offDays":2,"anchor":"2026-10-23","anchorIsWork":false}',
      )!;
      expect(back.overrides, isEmpty);
      expect(back.dayTypeOf(d(25)), DayType.work);
    });

    test('damaged override entries are skipped, the good ones stay', () {
      final back = WorkSchedule.tryParse(jsonEncode({
        'workDays': 2,
        'offDays': 2,
        'anchor': '2026-10-23',
        'overrides': {
          '2026-10-25': 'off',
          'not a date': 'off',
          '2026-10-27': 'holiday',
          '2026-10-28': 5,
        },
      }))!;
      expect(back.overrides, {d(25): DayType.off});
    });

    test('overrides that are not a map are ignored', () {
      final back = WorkSchedule.tryParse(jsonEncode({
        'workDays': 2,
        'offDays': 2,
        'anchor': '2026-10-23',
        'overrides': ['2026-10-25'],
      }))!;
      expect(back.overrides, isEmpty);
    });

    test('they are part of the full backup', () {
      final s = with_({d(25): DayType.off, d(27): DayType.work});
      final data = FileTransfer.buildFullBackup(
        templates: const [],
        notes: const [],
        history: const [],
        standardTasks: const [],
        trackedActivities: const [],
        workSchedule: s,
      );
      final viaFile = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
      final result = FileTransfer.workScheduleOfBackup(viaFile);
      expect(result.apply, isTrue);
      expect(result.schedule!.overrides,
          {d(25): DayType.off, d(27): DayType.work});
    });
  });

  group('plan generator follows the overrides', () {
    final work = template('Work', templateTargetWork);
    final offs = [
      for (var i = 1; i <= 4; i++) template('Выходной $i', templateTargetOff),
    ];

    Map<int, String> names(WorkSchedule schedule, int from, int to) {
      final p = previewPlanGeneration(
        dates: [for (var day = from; day <= to; day++) d(day)],
        schedule: schedule,
        templates: [work, ...offs],
        hasPlan: (_) => false,
      );
      return {for (final x in p.toCreate) x.date.day: x.template.name};
    }

    test('a holiday gets the next day-off template, later days move on', () {
      expect(names(with_({d(25): DayType.off}), 23, 28), {
        23: 'Выходной 1',
        24: 'Выходной 2',
        25: 'Выходной 3',
        26: 'Work',
        27: 'Выходной 4',
        28: 'Выходной 1',
      });
    });

    test('a day made a work day gets the work template and leaves the cycle',
        () {
      expect(names(with_({d(27): DayType.work}), 27, 28), {
        27: 'Work',
        28: 'Выходной 3',
      });
    });

    test('without overrides it is the plain rotation', () {
      expect(names(base(), 23, 28), {
        23: 'Выходной 1',
        24: 'Выходной 2',
        25: 'Work',
        26: 'Work',
        27: 'Выходной 3',
        28: 'Выходной 4',
      });
    });
  });
}
