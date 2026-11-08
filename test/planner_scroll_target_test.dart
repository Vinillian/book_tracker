import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/planner_scroll_target.dart';

void main() {
  Node plan(String name, DateTime? date) => Node(
        name: name,
        children: [],
        stepType: 'folder',
        plannedDate: date,
      );

  group('findRelevantPlanIndex', () {
    final today = DateTime(2026, 11, 8);

    test('selects today when it exists', () {
      final plans = [
        plan('Завтра', DateTime(2026, 11, 9)),
        plan('Сегодня', DateTime(2026, 11, 8)),
        plan('Вчера', DateTime(2026, 11, 7)),
      ];

      expect(findRelevantPlanIndex(plans, today), 1);
    });

    test('selects the nearest past day when today is absent', () {
      final plans = [
        plan('Завтра', DateTime(2026, 11, 9)),
        plan('Три дня назад', DateTime(2026, 11, 5)),
        plan('Вчера', DateTime(2026, 11, 7)),
      ];

      expect(findRelevantPlanIndex(plans, today), 2);
    });

    test('selects the nearest future day when there are no past days', () {
      final plans = [
        plan('Через два дня', DateTime(2026, 11, 10)),
        plan('Завтра', DateTime(2026, 11, 9)),
      ];

      expect(findRelevantPlanIndex(plans, today), 1);
    });

    test('returns null when no plan has a date', () {
      final plans = [
        plan('Без даты', null),
        plan('Ещё один план', null),
      ];

      expect(findRelevantPlanIndex(plans, today), isNull);
    });
  });
}
