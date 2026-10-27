import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/utils/file_transfer.dart';
import 'package:book_tracker/utils/work_schedule.dart';

Map<String, dynamic> backup({WorkSchedule? schedule}) =>
    FileTransfer.buildFullBackup(
      templates: [
        {'name': 'T'},
      ],
      notes: const [],
      history: const [],
      standardTasks: const [],
      trackedActivities: const [],
      workSchedule: schedule,
    );

/// What a backup looks like after it was written to a file and read back.
Map<String, dynamic> viaJson(Map<String, dynamic> data) =>
    jsonDecode(jsonEncode(data)) as Map<String, dynamic>;

void main() {
  final schedule = WorkSchedule(
    workDays: 2,
    offDays: 2,
    anchor: DateTime(2026, 10, 23),
  );

  group('buildFullBackup', () {
    test('keeps the five lists and adds the schedule', () {
      final data = backup(schedule: schedule);
      expect(
        data.keys,
        containsAll([
          'templates',
          'notes',
          'history',
          'standardTasks',
          'trackedActivities',
          'workSchedule',
        ]),
      );
      expect(data['templates'], [
        {'name': 'T'},
      ]);
      expect(data['workSchedule'], schedule.toJson());
    });

    test('writes the key with null when there is no schedule', () {
      final data = backup();
      expect(data.containsKey('workSchedule'), isTrue);
      expect(data['workSchedule'], isNull);
    });
  });

  group('workScheduleOfBackup', () {
    test('a schedule survives writing and reading a backup', () {
      final result = FileTransfer.workScheduleOfBackup(
        viaJson(backup(schedule: schedule)),
      );
      expect(result.apply, isTrue);
      final read = result.schedule!;
      expect(read.workDays, 2);
      expect(read.offDays, 2);
      expect(read.anchor, DateTime(2026, 10, 23));
      expect(read.anchorIsWork, isFalse);
      expect(read.dayTypeOf(DateTime(2026, 10, 25)), DayType.work);
      expect(read.dayTypeOf(DateTime(2026, 10, 27)), DayType.off);
    });

    test('anchorIsWork and a 5 / 2 schedule are kept', () {
      final weekly = WorkSchedule(
        workDays: 5,
        offDays: 2,
        anchor: DateTime(2026, 10, 26),
        anchorIsWork: true,
      );
      final read = FileTransfer.workScheduleOfBackup(
        viaJson(backup(schedule: weekly)),
      ).schedule!;
      expect(read.workDays, 5);
      expect(read.offDays, 2);
      expect(read.anchorIsWork, isTrue);
    });

    test('a backup without a schedule restores "no schedule"', () {
      final result = FileTransfer.workScheduleOfBackup(viaJson(backup()));
      expect(result.apply, isTrue);
      expect(result.schedule, isNull);
    });

    test('an old backup without the key leaves the current schedule alone', () {
      final old = viaJson(backup(schedule: schedule))..remove('workSchedule');
      final result = FileTransfer.workScheduleOfBackup(old);
      expect(result.apply, isFalse);
      expect(result.schedule, isNull);
    });

    test('a damaged entry leaves the current schedule alone', () {
      for (final bad in <Object>[
        'text',
        42,
        <String, dynamic>{'workDays': 0, 'offDays': 2, 'anchor': '2026-10-23'},
        <String, dynamic>{'workDays': 2, 'offDays': 2},
        <String, dynamic>{'workDays': 2, 'offDays': 2, 'anchor': 'not a date'},
      ]) {
        final result = FileTransfer.workScheduleOfBackup({'workSchedule': bad});
        expect(result.apply, isFalse, reason: '$bad');
        expect(result.schedule, isNull, reason: '$bad');
      }
    });
  });
}
