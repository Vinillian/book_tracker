import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/screens/editor_screen.dart';

void main() {
  testWidgets(
    'day-plan editor sorts timed tasks and exposes drag only for untimed tasks',
    (tester) async {
      final day = Node(
        name: 'План на день',
        category: 'planner',
        children: [
          Node.leaf('Вечерняя прогулка')..startMinutes = 19 * 60,
          Node.leaf('Задача без времени'),
          Node.leaf('Утренняя практика')..startMinutes = 7 * 60 + 30,
        ],
      );

      await tester.pumpWidget(MaterialApp(home: EditorScreen(node: day)));
      await tester.pumpAndSettle();

      final morningY = tester.getTopLeft(find.text('Утренняя практика')).dy;
      final eveningY = tester.getTopLeft(find.text('Вечерняя прогулка')).dy;
      final untimedY = tester.getTopLeft(find.text('Задача без времени')).dy;

      expect(morningY, lessThan(eveningY));
      expect(eveningY, lessThan(untimedY));
      expect(find.byIcon(Icons.schedule), findsNWidgets(2));
      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
    },
  );

  testWidgets('long-press multi-select does not expose a drag handle', (
    tester,
  ) async {
    final day = Node(
      name: 'План на день',
      category: 'planner',
      children: [
        Node.leaf('Задача без времени'),
        Node.leaf('Задача на 10')..startMinutes = 10 * 60,
      ],
    );

    await tester.pumpWidget(MaterialApp(home: EditorScreen(node: day)));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Задача без времени'));
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(find.text('Выбрано: 1'), findsOneWidget);
  });
}
