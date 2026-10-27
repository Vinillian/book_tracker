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
}
