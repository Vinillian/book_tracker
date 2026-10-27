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
}
