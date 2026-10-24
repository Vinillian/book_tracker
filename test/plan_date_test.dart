import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/plan_date.dart';

Node day(String name, {DateTime? plannedDate}) => Node(
      name: name,
      plannedDate: plannedDate,
      category: 'planner',
      stepType: 'folder',
      children: [],
    );

void main() {
  group('parseLegacyPlanName', () {
    test('parses dd.MM.yyyy', () {
      expect(parseLegacyPlanName('24.10.2026'), DateTime(2026, 10, 24));
      expect(parseLegacyPlanName('05.11.2026'), DateTime(2026, 11, 5));
    });

    test('returns null for anything that is not such a date', () {
      expect(parseLegacyPlanName('Мой день'), isNull);
      expect(parseLegacyPlanName('2026-10-24'), isNull);
      expect(parseLegacyPlanName(''), isNull);
    });
  });

  group('planDateOf (#114)', () {
    test('uses plannedDate and drops the time of day', () {
      final n = day('Мой день', plannedDate: DateTime(2026, 10, 24, 15, 30));
      expect(planDateOf(n), DateTime(2026, 10, 24));
    });

    test('plannedDate wins over a legacy date in the name', () {
      final n = day('01.01.2026', plannedDate: DateTime(2026, 10, 24));
      expect(planDateOf(n), DateTime(2026, 10, 24));
    });

    test('falls back to the legacy name when plannedDate is missing', () {
      expect(planDateOf(day('05.11.2026')), DateTime(2026, 11, 5));
    });

    test('is null for a free title without plannedDate', () {
      expect(planDateOf(day('Мой день')), isNull);
    });
  });
}
