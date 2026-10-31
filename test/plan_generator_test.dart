import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/plan_generator.dart';
import 'package:book_tracker/utils/template_target.dart';
import 'package:book_tracker/utils/work_schedule.dart';

Node template(String name, String? target) => Node(
      name: name,
      children: [Node.leaf('a')],
      category: 'template',
      templateTarget: target,
    );

// The author's schedule: 2 on / 2 off, 23.10.2026 is the first day off.
WorkSchedule twoOnTwoOff() => WorkSchedule(
      workDays: 2,
      offDays: 2,
      anchor: DateTime(2026, 10, 23),
    );

DateTime d(int day) => DateTime(2026, 10, day);

void main() {
  group('datesInRange', () {
    test('includes both ends', () {
      final days = datesInRange(d(25), d(28));
      expect(days, [d(25), d(26), d(27), d(28)]);
    });

    test('one day when from == to, and time of day is ignored', () {
      expect(datesInRange(DateTime(2026, 10, 25, 18, 30), d(25)), [d(25)]);
    });

    test('empty when the end is before the start', () {
      expect(datesInRange(d(28), d(25)), isEmpty);
    });

    test('keeps counting across a month end and a daylight saving change', () {
      expect(datesInRange(DateTime(2026, 10, 30), DateTime(2026, 11, 2)).length,
          4);
      expect(datesInRange(DateTime(2027, 3, 25), DateTime(2027, 3, 31)).length,
          7);
      expect(datesInRange(DateTime(2026, 10, 24), DateTime(2026, 10, 26)).last,
          DateTime(2026, 10, 26));
    });
  });

  group('previewPlanGeneration', () {
    final work = template('Work', templateTargetWork);
    final off = template('Off', templateTargetOff);

    PlanGenerationPreview run({
      List<Node>? templates,
      bool Function(DateTime)? hasPlan,
      List<DateTime>? dates,
    }) =>
        previewPlanGeneration(
          dates: dates ?? datesInRange(d(25), d(28)),
          schedule: twoOnTwoOff(),
          templates: templates ?? [work, off],
          hasPlan: hasPlan ?? ((_) => false),
        );

    test('each day gets the template of its type, in date order', () {
      final p = run();
      expect(p.toCreate.map((e) => e.date), [d(25), d(26), d(27), d(28)]);
      expect(p.toCreate.map((e) => e.type),
          [DayType.work, DayType.work, DayType.off, DayType.off]);
      expect(p.toCreate[0].template, same(work));
      expect(p.toCreate[2].template, same(off));
      expect(p.workCount, 2);
      expect(p.offCount, 2);
      expect(p.existing, isEmpty);
      expect(p.withoutTemplate, isEmpty);
      expect(p.missingTemplates, isEmpty);
    });

    test('days that already have a plan are skipped and listed', () {
      final p = run(hasPlan: (date) => date == d(26) || date == d(27));
      expect(p.toCreate.map((e) => e.date), [d(25), d(28)]);
      expect(p.existing, [d(26), d(27)]);
    });

    test('a day without a template is left out and the type is reported', () {
      final p = run(templates: [off]);
      expect(p.toCreate.map((e) => e.date), [d(27), d(28)]);
      expect(p.withoutTemplate, [d(25), d(26)]);
      expect(p.missingTemplates, {DayType.work});
    });

    test('no templates at all: nothing is created, both types are missing', () {
      final p = run(templates: []);
      expect(p.toCreate, isEmpty);
      expect(p.withoutTemplate.length, 4);
      expect(p.missingTemplates, {DayType.work, DayType.off});
    });

    test('plain day templates and old templates are not guessed', () {
      final p = run(templates: [
        template('Day', templateTargetDay),
        template('Old', null),
        template('Book', templateTargetBook),
      ]);
      expect(p.toCreate, isEmpty);
      expect(p.missingTemplates, {DayType.work, DayType.off});
    });

    test('an existing plan wins over a missing template', () {
      final p = run(templates: [off], hasPlan: (date) => date == d(25));
      expect(p.existing, [d(25)]);
      expect(p.withoutTemplate, [d(26)]);
    });

    test('the first template of a type is used', () {
      final second = template('Work 2', templateTargetWork);
      final p = run(templates: [off, work, second]);
      expect(p.toCreate.first.template, same(work));
    });

    test('an empty period creates nothing', () {
      final p = run(dates: const []);
      expect(p.toCreate, isEmpty);
      expect(p.existing, isEmpty);
      expect(p.withoutTemplate, isEmpty);
    });
  });

  group('dayHasProgress', () {
    Node day(List<Node> children) =>
        Node(name: 'D', children: children, category: 'planner');

    test('a clean day has none', () {
      expect(dayHasProgress(day([Node.leaf('a'), Node.leaf('b')])), isFalse);
      expect(dayHasProgress(day([])), isFalse);
    });

    test('a ticked task, finished steps or logged time count', () {
      expect(dayHasProgress(day([Node.leaf('a')..completed = true])), isTrue);
      expect(
          dayHasProgress(day([
            Node.leaf('s', stepType: 'stepByStep', totalSteps: 3)
              ..completedSteps = 1,
          ])),
          isTrue);
      expect(
          dayHasProgress(day([
            Node.leaf('t', stepType: 'duration')..loggedMinutes = 10,
          ])),
          isTrue);
    });

    test('progress deep in the tree counts', () {
      final deep = Node(
        name: 'g',
        children: [Node.leaf('x')..completed = true],
        stepType: 'folder',
      );
      expect(dayHasProgress(day([deep])), isTrue);
    });
  });

  group('previewPlanDeletion', () {
    Node plan(int dayOfMonth, {bool done = false}) => Node(
          name: 'p$dayOfMonth',
          children: [Node.leaf('a')..completed = done],
          category: 'planner',
          plannedDate: d(dayOfMonth),
        );

    final p25 = plan(25);
    final p26 = plan(26, done: true);
    final p27 = plan(27);
    final p30 = plan(30);

    test('only plans inside the period, in date order', () {
      final r = previewPlanDeletion(
        dates: datesInRange(d(25), d(28)),
        plans: [p30, p27, p25],
        keepDaysWithProgress: true,
      );
      expect(r.toDelete, [p25, p27]);
      expect(r.keptWithProgress, isEmpty);
    });

    test('days with progress are kept when asked', () {
      final r = previewPlanDeletion(
        dates: datesInRange(d(25), d(28)),
        plans: [p25, p26, p27],
        keepDaysWithProgress: true,
      );
      expect(r.toDelete, [p25, p27]);
      expect(r.keptWithProgress, [p26]);
      expect(r.deletedWithProgress, 0);
    });

    test('with the option off they are deleted and counted', () {
      final r = previewPlanDeletion(
        dates: datesInRange(d(25), d(28)),
        plans: [p25, p26, p27],
        keepDaysWithProgress: false,
      );
      expect(r.toDelete, [p25, p26, p27]);
      expect(r.keptWithProgress, isEmpty);
      expect(r.deletedWithProgress, 1);
    });

    test('both ends of the period are included', () {
      final r = previewPlanDeletion(
        dates: datesInRange(d(25), d(27)),
        plans: [p25, p27],
        keepDaysWithProgress: true,
      );
      expect(r.toDelete, [p25, p27]);
    });

    test('a plan without a date is never matched', () {
      final undated = Node(
        name: 'Free title',
        children: [Node.leaf('a')],
        category: 'planner',
      );
      final r = previewPlanDeletion(
        dates: datesInRange(d(1), d(31)),
        plans: [undated],
        keepDaysWithProgress: false,
      );
      expect(r.toDelete, isEmpty);
    });

    test('a legacy plan named by its date is matched', () {
      final legacy = Node(
        name: '26.10.2026',
        children: [Node.leaf('a')],
        category: 'planner',
      );
      final r = previewPlanDeletion(
        dates: datesInRange(d(25), d(28)),
        plans: [legacy],
        keepDaysWithProgress: true,
      );
      expect(r.toDelete, [legacy]);
    });

    test('nothing in the period means nothing to delete', () {
      final r = previewPlanDeletion(
        dates: datesInRange(d(1), d(5)),
        plans: [p25, p26],
        keepDaysWithProgress: false,
      );
      expect(r.toDelete, isEmpty);
      expect(r.deletedWithProgress, 0);
    });
  });

  group('offDayOrdinalOf', () {
    test('counts the days off from the anchor, null for work days', () {
      final schedule = twoOnTwoOff(); // 23.10 and 24.10 are days off
      expect(schedule.offDayOrdinalOf(d(23)), 0);
      expect(schedule.offDayOrdinalOf(d(24)), 1);
      expect(schedule.offDayOrdinalOf(d(25)), isNull);
      expect(schedule.offDayOrdinalOf(d(26)), isNull);
      expect(schedule.offDayOrdinalOf(d(27)), 2);
      expect(schedule.offDayOrdinalOf(d(28)), 3);
      expect(schedule.offDayOrdinalOf(d(31)), 4);
    });

    test('continues backwards before the anchor', () {
      final schedule = twoOnTwoOff();
      expect(schedule.offDayOrdinalOf(d(22)), isNull);
      expect(schedule.offDayOrdinalOf(d(21)), isNull);
      expect(schedule.offDayOrdinalOf(d(20)), -1);
      expect(schedule.offDayOrdinalOf(d(19)), -2);
    });

    test('anchor on a work block: days off start after it', () {
      final schedule = WorkSchedule(
        workDays: 2,
        offDays: 2,
        anchor: d(23),
        anchorIsWork: true,
      );
      expect(schedule.offDayOrdinalOf(d(23)), isNull);
      expect(schedule.offDayOrdinalOf(d(24)), isNull);
      expect(schedule.offDayOrdinalOf(d(25)), 0);
      expect(schedule.offDayOrdinalOf(d(26)), 1);
      expect(schedule.offDayOrdinalOf(d(29)), 2);
      expect(schedule.offDayOrdinalOf(d(30)), 3);
    });

    test('5 on / 2 off from a Monday: Saturday and Sunday count 0, 1, 2...', () {
      final schedule = WorkSchedule(
        workDays: 5,
        offDays: 2,
        anchor: DateTime(2026, 10, 26), // a Monday
        anchorIsWork: true,
      );
      expect(schedule.offDayOrdinalOf(DateTime(2026, 10, 31)), 0);
      expect(schedule.offDayOrdinalOf(DateTime(2026, 11, 1)), 1);
      expect(schedule.offDayOrdinalOf(DateTime(2026, 11, 7)), 2);
      expect(schedule.offDayOrdinalOf(DateTime(2026, 11, 2)), isNull);
    });

    test('is non-null exactly on days off and grows by one each time', () {
      final schedule = WorkSchedule(
        workDays: 3,
        offDays: 2,
        anchor: d(23),
        anchorIsWork: true,
      );
      int? previous;
      for (var i = -20; i < 60; i++) {
        final date = DateTime(2026, 10, 23 + i);
        final ordinal = schedule.offDayOrdinalOf(date);
        expect(ordinal != null, schedule.dayTypeOf(date) == DayType.off);
        if (ordinal != null) {
          if (previous != null) expect(ordinal, previous + 1);
          previous = ordinal;
        }
      }
    });
  });

  group('compareNamesNaturally / templatesForDayType', () {
    test('numbers sort as numbers, case is ignored', () {
      final names = ['Выходной 10', 'выходной 2', 'Выходной 1'];
      names.sort(compareNamesNaturally);
      expect(names, ['Выходной 1', 'выходной 2', 'Выходной 10']);
    });

    test('leading zeros and prefixes', () {
      expect(compareNamesNaturally('Выходной 02', 'Выходной 10'), lessThan(0));
      expect(compareNamesNaturally('Выходной', 'Выходной 1'), lessThan(0));
      expect(compareNamesNaturally('Лес', 'лес'), 0);
    });

    test('only day-off templates, ordered by name, equal names stay in order',
        () {
      final o3 = template('Выходной 3', templateTargetOff);
      final o1 = template('Выходной 1', templateTargetOff);
      final o10 = template('Выходной 10', templateTargetOff);
      final o2a = template('Выходной 2', templateTargetOff);
      final o2b = template('выходной 2', templateTargetOff);
      final work = template('Work', templateTargetWork);
      final plain = template('Plain', templateTargetDay);
      final result = templatesForDayType(
        [o3, work, o10, o2b, plain, o1, o2a],
        DayType.off,
      );
      expect(result, [o1, o2b, o2a, o3, o10]);
    });

    test('no day-off templates gives an empty list', () {
      expect(
        templatesForDayType([template('W', templateTargetWork)], DayType.off),
        isEmpty,
      );
    });
  });

  group('rotation of day-off templates', () {
    final work = template('Work', templateTargetWork);
    final o1 = template('Выходной 1', templateTargetOff);
    final o2 = template('Выходной 2', templateTargetOff);
    final o3 = template('Выходной 3', templateTargetOff);
    final o4 = template('Выходной 4', templateTargetOff);
    // Deliberately not in name order.
    final shuffled = [o3, work, o1, o4, o2];

    PlanGenerationPreview run(
      DateTime from,
      DateTime to, {
      List<Node>? templates,
      bool Function(DateTime)? hasPlan,
    }) =>
        previewPlanGeneration(
          dates: datesInRange(from, to),
          schedule: twoOnTwoOff(),
          templates: templates ?? shuffled,
          hasPlan: hasPlan ?? ((_) => false),
        );

    test('days off take the templates in name order, round and round', () {
      final p = run(d(23), d(31));
      final names = {
        for (final day in p.toCreate) day.date.day: day.template.name,
      };
      expect(names, {
        23: 'Выходной 1',
        24: 'Выходной 2',
        25: 'Work',
        26: 'Work',
        27: 'Выходной 3',
        28: 'Выходной 4',
        29: 'Work',
        30: 'Work',
        31: 'Выходной 1',
      });
      expect(p.offRotation, [o1, o2, o3, o4]);
    });

    test('a later period continues the sequence', () {
      final p = run(d(27), d(28));
      expect(p.toCreate.map((e) => e.template), [o3, o4]);
    });

    test('a day that already has a plan keeps its place in the cycle', () {
      final p = run(d(27), d(28), hasPlan: (date) => date == d(27));
      expect(p.existing, [d(27)]);
      expect(p.toCreate.map((e) => e.template), [o4]);
    });

    test('a single day-off template is used everywhere, as before', () {
      final p = run(d(23), d(31), templates: [work, o2]);
      expect(
        p.toCreate.where((e) => e.type == DayType.off).map((e) => e.template),
        everyElement(same(o2)),
      );
      expect(p.offRotation, [o2]);
    });

    test('ten templates: "Выходной 10" comes last, not second', () {
      final ten = [
        for (var i = 10; i >= 1; i--) template('Выходной $i', templateTargetOff),
      ];
      final p = run(d(23), d(24), templates: [work, ...ten]);
      expect(p.offRotation.map((t) => t.name).last, 'Выходной 10');
      expect(p.toCreate.map((e) => e.template.name),
          ['Выходной 1', 'Выходной 2']);
    });
  });
}
