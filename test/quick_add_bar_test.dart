import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/screens/components/quick_add_bar.dart';

void main() {
  Future<List<(String, int?)>> pumpBar(
    WidgetTester tester, {
    Future<TimeOfDay?> Function(BuildContext, TimeOfDay)? timePicker,
  }) async {
    final added = <(String, int?)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickAddBar(
            onAdd: (name, startMinutes) => added.add((name, startMinutes)),
            onOpenPicker: (_) {},
            timePicker: timePicker,
          ),
        ),
      ),
    );
    return added;
  }

  testWidgets('Enter adds the trimmed name and clears the field', (
    tester,
  ) async {
    final added = await pumpBar(tester);
    await tester.enterText(find.byType(TextField), '  Прогулка  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(added, [('Прогулка', null)]);
    expect(find.text('Прогулка'), findsNothing);
  });

  testWidgets('empty or blank input adds nothing', (tester) async {
    final added = await pumpBar(tester);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    expect(added, isEmpty);
  });

  testWidgets('the send button adds too', (tester) async {
    final added = await pumpBar(tester);
    await tester.enterText(find.byType(TextField), 'Зарядка');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    expect(added, [('Зарядка', null)]);
  });

  testWidgets('selected time is attached to a typed quick-add task', (
    tester,
  ) async {
    final added = await pumpBar(
      tester,
      timePicker: (_, _) async => const TimeOfDay(hour: 16, minute: 0),
    );

    await tester.tap(find.byTooltip('Назначить время'));
    await tester.pump();
    expect(find.byTooltip('Время: 16:00 · Изменить'), findsOneWidget);
    expect(find.text('16:00'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Основы математики');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(added, [('Основы математики', 16 * 60)]);
  });
}
