import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/standard_task.dart';
import 'package:book_tracker/screens/components/standard_task_quick_picker.dart';

void main() {
  final tasks = [
    StandardTask(name: 'Зарядка', stepType: 'single'),
    StandardTask(name: 'Чтение', stepType: 'stepByStep', totalSteps: 3),
    StandardTask(
      name: 'Бег',
      stepType: 'duration',
      targetMinutes: 45,
      trackingId: 'running',
    ),
  ];

  Future<List<(StandardTask, int?)>> pumpList(
    WidgetTester tester,
    List<StandardTask> items, {
    int? startMinutes,
  }) async {
    final picked = <(StandardTask, int?)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StandardTaskQuickPickerList(
            tasks: items,
            startMinutes: startMinutes,
            onPick: (task, minutes) => picked.add((task, minutes)),
          ),
        ),
      ),
    );
    return picked;
  }

  testWidgets('lists the tasks with their type', (tester) async {
    await pumpList(tester, tasks);
    expect(find.text('Зарядка'), findsOneWidget);
    expect(find.text('Чтение'), findsOneWidget);
    expect(find.text('Одиночный чекбокс'), findsOneWidget);
    expect(find.text('Пошаговый (3 шагов)'), findsOneWidget);
    expect(find.text('Одиночный чекбокс · цель времени: 45 мин'), findsOneWidget);
  });

  testWidgets('search filters by name, ignoring case', (tester) async {
    await pumpList(tester, tasks);
    await tester.enterText(find.byType(TextField), 'ЗАР');
    await tester.pump();
    expect(find.text('Зарядка'), findsOneWidget);
    expect(find.text('Чтение'), findsNothing);
  });

  testWidgets('search with no match shows a hint', (tester) async {
    await pumpList(tester, tasks);
    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump();
    expect(find.text('Ничего не найдено'), findsOneWidget);
  });

  testWidgets('an empty list tells where to create tasks', (tester) async {
    await pumpList(tester, const []);
    expect(
      find.text('Нет стандартных задач. Создайте их в меню.'),
      findsOneWidget,
    );
  });

  testWidgets('a tap adds right away and counts repeated additions',
      (tester) async {
    final picked = await pumpList(tester, tasks);
    expect(find.textContaining('✓'), findsNothing);

    await tester.tap(find.text('Зарядка'));
    await tester.pump();
    expect(picked, [(tasks[0], null)]);
    expect(find.text('✓ ×1'), findsOneWidget);

    await tester.tap(find.text('Зарядка'));
    await tester.pump();
    expect(picked, [(tasks[0], null), (tasks[0], null)]);
    expect(find.text('✓ ×2'), findsOneWidget);

    // The list is still there: several different tasks in a row.
    await tester.tap(find.text('Чтение'));
    await tester.pump();
    expect(picked, [
      (tasks[0], null),
      (tasks[0], null),
      (tasks[1], null),
    ]);

    await tester.tap(find.text('Бег'));
    await tester.pump();
    expect(picked.last.$1.stepType, 'single');
    expect(picked.last.$1.targetMinutes, 45);
    expect(picked.last.$1.trackingId, 'running');
    expect(picked.last.$2, isNull);
  });
}


  testWidgets('passes the selected start time with every picked task',
      (tester) async {
    const startMinutes = 16 * 60;
    final picked = await pumpList(
      tester,
      tasks,
      startMinutes: startMinutes,
    );

    await tester.tap(find.text('Чтение'));
    await tester.pump();
    expect(picked, [(tasks[1], startMinutes)]);
  });
