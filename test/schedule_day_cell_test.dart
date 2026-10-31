import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/screens/components/schedule_day_cell.dart';
import 'package:book_tracker/utils/work_schedule.dart';

Future<void> pumpCell(WidgetTester tester, Widget cell, {double width = 60}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        home: Scaffold(
          body: Center(child: SizedBox(width: width, height: 60, child: cell)),
        ),
      ),
    );

BoxDecoration decorationOf(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(ScheduleDayCell),
      matching: find.byType(Container),
    ),
  );
  return container.decoration! as BoxDecoration;
}

ColorScheme schemeOf(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(ScheduleDayCell))).colorScheme;

Color? textColorOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.color;

void main() {
  test('day types have their colors', () {
    expect(dayTypeColor(DayType.work), Colors.orange);
    expect(dayTypeColor(DayType.off), Colors.green);
  });

  group('ScheduleDayCell', () {
    testWidgets('shows the day number', (tester) async {
      await pumpCell(tester, const ScheduleDayCell(dayNumber: 17, type: DayType.work));
      expect(find.text('17'), findsOneWidget);
    });

    testWidgets('a work day and a day off get their own tint', (tester) async {
      await pumpCell(tester, const ScheduleDayCell(dayNumber: 3, type: DayType.work));
      var deco = decorationOf(tester);
      expect(deco.shape, BoxShape.circle);
      expect(deco.color, Colors.orange.withValues(alpha: 0.22));
      expect(deco.border, isNull);

      await pumpCell(tester, const ScheduleDayCell(dayNumber: 3, type: DayType.off));
      deco = decorationOf(tester);
      expect(deco.color, Colors.green.withValues(alpha: 0.22));
      expect(deco.border, isNull);
    });

    testWidgets('a day set by hand has an outline in the color of its type',
        (tester) async {
      await pumpCell(
        tester,
        const ScheduleDayCell(dayNumber: 3, type: DayType.off, overridden: true),
      );
      final border = decorationOf(tester).border! as Border;
      expect(border.top.color, Colors.green);
      expect(border.top.width, 1.5);

      await pumpCell(
        tester,
        const ScheduleDayCell(dayNumber: 3, type: DayType.work, overridden: true),
      );
      expect((decorationOf(tester).border! as Border).top.color, Colors.orange);
    });

    testWidgets('today has a ring in the accent color', (tester) async {
      await pumpCell(
        tester,
        const ScheduleDayCell(dayNumber: 3, type: DayType.work, today: true),
      );
      final border = decorationOf(tester).border! as Border;
      expect(border.top.color, schemeOf(tester).primary);
      expect(border.top.width, 2);
      expect(decorationOf(tester).color, Colors.orange.withValues(alpha: 0.22));
    });

    testWidgets('today wins over "set by hand"', (tester) async {
      await pumpCell(
        tester,
        const ScheduleDayCell(
          dayNumber: 3,
          type: DayType.off,
          today: true,
          overridden: true,
        ),
      );
      final border = decorationOf(tester).border! as Border;
      expect(border.top.color, schemeOf(tester).primary);
    });

    testWidgets('the selected day is filled with the accent color',
        (tester) async {
      await pumpCell(
        tester,
        const ScheduleDayCell(
          dayNumber: 9,
          type: DayType.off,
          selected: true,
          today: true,
          overridden: true,
        ),
      );
      final scheme = schemeOf(tester);
      final deco = decorationOf(tester);
      expect(deco.color, scheme.primary);
      expect(deco.border, isNull);
      expect(textColorOf(tester, '9'), scheme.onPrimary);
    });

    testWidgets('dates of the neighbouring months are dimmed', (tester) async {
      await pumpCell(
        tester,
        const ScheduleDayCell(dayNumber: 30, type: DayType.work, outside: true),
      );
      expect(decorationOf(tester).color, Colors.orange.withValues(alpha: 0.08));
      expect(
        textColorOf(tester, '30'),
        schemeOf(tester).onSurface.withValues(alpha: 0.4),
      );
    });
  });

  testWidgets('ScheduleLegend names the three kinds of dates', (tester) async {
    // The legend is a row of labels: it needs the width of a screen, not of a cell.
    await pumpCell(tester, const ScheduleLegend(), width: 400);
    expect(find.text('Рабочий день'), findsOneWidget);
    expect(find.text('Выходной'), findsOneWidget);
    expect(find.text('Изменён вручную'), findsOneWidget);
  });
}
