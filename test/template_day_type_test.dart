import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/template_target.dart';
import 'package:book_tracker/utils/work_schedule.dart';

Node template(String name, String? target) => Node(
      name: name,
      children: [Node.leaf('a')],
      category: 'template',
      templateTarget: target,
    );

void main() {
  group('templateMatchesTarget with day types', () {
    test('a day screen is offered day, work, off and old templates', () {
      for (final t in [
        templateTargetDay,
        templateTargetWork,
        templateTargetOff,
        null,
      ]) {
        expect(templateMatchesTarget(template('T', t), templateTargetDay),
            isTrue,
            reason: 'target $t');
      }
      expect(
        templateMatchesTarget(
            template('T', templateTargetBook), templateTargetDay),
        isFalse,
      );
    });

    test('a book screen is not offered day-type templates', () {
      expect(
        templateMatchesTarget(
            template('T', templateTargetWork), templateTargetBook),
        isFalse,
      );
      expect(
        templateMatchesTarget(
            template('T', templateTargetOff), templateTargetBook),
        isFalse,
      );
    });

    test('a filter for work days keeps only work and old templates', () {
      expect(
        templateMatchesTarget(
            template('T', templateTargetWork), templateTargetWork),
        isTrue,
      );
      expect(
        templateMatchesTarget(
            template('T', templateTargetOff), templateTargetWork),
        isFalse,
      );
      expect(
        templateMatchesTarget(
            template('T', templateTargetDay), templateTargetWork),
        isFalse,
      );
      expect(templateMatchesTarget(template('T', null), templateTargetWork),
          isTrue);
    });
  });

  group('templateForDayType', () {
    final plain = template('Любой', null);
    final day = template('День', templateTargetDay);
    final work = template('Рабочий', templateTargetWork);
    final off = template('Выходной', templateTargetOff);
    final work2 = template('Рабочий 2', templateTargetWork);

    test('picks the template made for the day type', () {
      final all = [plain, day, off, work];
      expect(templateForDayType(all, DayType.work), same(work));
      expect(templateForDayType(all, DayType.off), same(off));
    });

    test('takes the first one when there are several', () {
      expect(templateForDayType([work, work2], DayType.work), same(work));
      expect(templateForDayType([work2, work], DayType.work), same(work2));
    });

    test('plain day and any templates are never guessed', () {
      expect(templateForDayType([plain, day], DayType.work), isNull);
      expect(templateForDayType([plain, day, work], DayType.off), isNull);
      expect(templateForDayType(const [], DayType.work), isNull);
    });

    test('target and label of a day type', () {
      expect(templateTargetForDayType(DayType.work), 'work');
      expect(templateTargetForDayType(DayType.off), 'off');
      expect(templateTargetLabel('work'), 'Рабочий день');
      expect(templateTargetLabel('off'), 'Выходной');
    });
  });
}
