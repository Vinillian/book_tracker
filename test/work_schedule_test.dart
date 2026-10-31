import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/utils/work_schedule.dart';

void main() {
  // The author's schedule: 2 on / 2 off, 23.10.2026 is the first day off.
  WorkSchedule twoOnTwoOff() => WorkSchedule(
        workDays: 2,
        offDays: 2,
        anchor: DateTime(2026, 10, 23),
        anchorIsWork: false,
      );

  group('dayTypeOf', () {
    test('2 on / 2 off from a day off', () {
      final s = twoOnTwoOff();
      DayType t(int d) => s.dayTypeOf(DateTime(2026, 10, d));
      expect(t(23), DayType.off);
      expect(t(24), DayType.off);
      expect(t(25), DayType.work);
      expect(t(26), DayType.work);
      expect(t(27), DayType.off);
      expect(t(28), DayType.off);
      expect(t(29), DayType.work);
      expect(t(30), DayType.work);
    });

    test('dates before the anchor continue the pattern backwards', () {
      final s = twoOnTwoOff();
      DayType t(int d) => s.dayTypeOf(DateTime(2026, 10, d));
      expect(t(22), DayType.work);
      expect(t(21), DayType.work);
      expect(t(20), DayType.off);
      expect(t(19), DayType.off);
    });

    test('works across a year boundary and a daylight saving change', () {
      final s = twoOnTwoOff();
      expect(s.dayTypeOf(DateTime(2027, 1, 1)), DayType.work);
      expect(s.dayTypeOf(DateTime(2027, 1, 2)), DayType.work);
      expect(s.dayTypeOf(DateTime(2027, 1, 3)), DayType.off);
      expect(s.dayTypeOf(DateTime(2027, 3, 28)), DayType.off);
      expect(s.dayTypeOf(DateTime(2027, 3, 29)), DayType.off);
      expect(s.dayTypeOf(DateTime(2027, 3, 30)), DayType.work);
    });

    test('the time of day is ignored', () {
      final s = twoOnTwoOff();
      expect(s.dayTypeOf(DateTime(2026, 10, 25, 23, 59)), DayType.work);
      expect(s.dayTypeOf(DateTime(2026, 10, 24, 0, 0)), DayType.off);
    });

    test('anchor is a work day, uneven blocks', () {
      final s = WorkSchedule(
        workDays: 3,
        offDays: 2,
        anchor: DateTime(2026, 1, 1),
        anchorIsWork: true,
      );
      DayType t(int d) => s.dayTypeOf(DateTime(2026, 1, d));
      expect([for (var d = 1; d <= 10; d++) t(d)], [
        DayType.work,
        DayType.work,
        DayType.work,
        DayType.off,
        DayType.off,
        DayType.work,
        DayType.work,
        DayType.work,
        DayType.off,
        DayType.off,
      ]);
    });
  });

  group('storage', () {
    test('encode / tryParse round trip', () {
      final parsed = WorkSchedule.tryParse(twoOnTwoOff().encode())!;
      expect(parsed.workDays, 2);
      expect(parsed.offDays, 2);
      expect(parsed.anchor, DateTime(2026, 10, 23));
      expect(parsed.anchorIsWork, isFalse);
      expect(parsed.dayTypeOf(DateTime(2026, 10, 25)), DayType.work);
    });

    test('the anchor loses its time of day', () {
      final s = WorkSchedule(
        workDays: 1,
        offDays: 1,
        anchor: DateTime(2026, 10, 23, 18, 30),
      );
      expect(s.anchor, DateTime(2026, 10, 23));
      expect(s.toJson()['anchor'], '2026-10-23');
    });

    test('missing or invalid data gives no schedule', () {
      expect(WorkSchedule.tryParse(null), isNull);
      expect(WorkSchedule.tryParse(''), isNull);
      expect(WorkSchedule.tryParse('not json'), isNull);
      expect(WorkSchedule.tryParse('[]'), isNull);
      expect(WorkSchedule.tryParse('{"workDays":0,"offDays":2,"anchor":"2026-10-23"}'), isNull);
      expect(WorkSchedule.tryParse('{"workDays":2,"offDays":2,"anchor":"nope"}'), isNull);
      expect(WorkSchedule.tryParse('{"workDays":"2","offDays":2,"anchor":"2026-10-23"}'), isNull);
    });
  });
}
