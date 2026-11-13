import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/models/standard_task.dart';
import 'package:book_tracker/models/tracked_activity.dart';
import 'package:book_tracker/providers/app_state.dart';
import 'package:book_tracker/screens/item_card_screen.dart';
import 'package:book_tracker/screens/standard_tasks_screen.dart';
import 'package:book_tracker/services/hive_startup.dart';

Future<void> _openEditor(
  WidgetTester tester,
  AppState appState,
  StandardTask task, {
  required bool isNew,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        StandardTaskEditorScreen(task: task, isNew: isNew),
                  ),
                ),
                child: const Text('Открыть редактор'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Открыть редактор'));
  await _pumpRouteTransition(tester);
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  // Avoid waiting for the blinking cursor of an autofocus TextField.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  late AppState appState;

  setUp(() async {
    registerAppHiveAdapters();
    final boxes = await HiveStartup(
      openBox: <T>(String name) => Hive.openBox<T>(name, bytes: Uint8List(0)),
    ).open();
    appState = AppState(
      templatesBox: boxes.templatesBox,
      notesBox: boxes.notesBox,
      historyBox: boxes.historyBox,
      standardTasksBox: boxes.standardTasksBox,
      trackedActivitiesBox: boxes.trackedActivitiesBox,
      settingsBox: boxes.settingsBox,
    );
  });

  tearDown(() async {
    appState.dispose();
    await Hive.close();
  });

  testWidgets(
    'creates a checkbox standard task with an optional time goal',
    (tester) async {
      await _openEditor(
        tester,
        appState,
        StandardTask(name: '', stepType: 'single'),
        isNew: true,
      );

      await tester.enterText(find.byType(TextField).first, 'Чтение');
      final targetField = find.byType(TextField).at(1);
      await tester.ensureVisible(targetField);
      await tester.enterText(targetField, '45');
      await tester.tap(find.byIcon(Icons.check));
      await _pumpRouteTransition(tester);

      expect(appState.standardTasks, hasLength(1));
      expect(appState.standardTasks.single.name, 'Чтение');
      expect(appState.standardTasks.single.stepType, 'single');
      expect(appState.standardTasks.single.targetMinutes, 45);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets('item-card picker copies step progress and time goal', (
    tester,
  ) async {
    appState.addStandardTask(
      StandardTask(
        name: 'Бег',
        stepType: 'stepByStep',
        totalSteps: 4,
        targetMinutes: 45,
        trackingId: 'running-standard-task',
      ),
    );

    Node? createdNode;
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  createdNode = await Navigator.of(context).push<Node>(
                    MaterialPageRoute(
                      builder: (_) => ItemCardScreen(
                        node: Node.leaf(''),
                        isNew: true,
                        quickAdd: true,
                      ),
                    ),
                  );
                },
                child: const Text('Добавить задачу'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Добавить задачу'));
    await _pumpRouteTransition(tester);
    await tester.tap(find.byTooltip('Выбрать из стандартных'));
    await _pumpRouteTransition(tester);
    await tester.tap(find.text('Бег'));
    await _pumpRouteTransition(tester);

    final targetField = find.byType(TextField).at(1);
    expect(tester.widget<TextField>(targetField).controller!.text, '45');

    await tester.tap(find.byIcon(Icons.check));
    await _pumpRouteTransition(tester);

    expect(createdNode, isNotNull);
    expect(createdNode!.stepType, 'stepByStep');
    expect(createdNode!.totalSteps, 4);
    expect(createdNode!.targetMinutes, 45);
    expect(createdNode!.trackingId, 'running-standard-task');
  });

  testWidgets(
    'editing legacy duration standard task keeps its time goal and tracking row',
    (tester) async {
      final task = StandardTask(
        name: 'Чтение',
        stepType: 'duration',
        targetMinutes: 60,
        trackingId: 'reading-tracking',
      );
      appState.addStandardTask(task);
      appState.addTrackedActivity(
        TrackedActivity(
          id: 'reading-activity',
          trackingId: 'reading-tracking',
          name: 'Чтение',
          colorValue: 0xFF2196F3,
          stepType: 'duration',
        ),
      );

      expect(task.stepType, 'single');
      await _openEditor(tester, appState, task, isNew: false);
      await tester.enterText(find.byType(TextField).first, 'Чтение книг');
      final targetField = find.byType(TextField).at(1);
      await tester.ensureVisible(targetField);
      await tester.enterText(targetField, '75');
      await tester.tap(find.byIcon(Icons.check));
      await _pumpRouteTransition(tester);

      final updatedTask = appState.standardTasks.single;
      final tracked = appState.trackedActivities.single;
      expect(updatedTask.name, 'Чтение книг');
      expect(updatedTask.stepType, 'single');
      expect(updatedTask.targetMinutes, 75);
      expect(updatedTask.trackingId, 'reading-tracking');
      expect(tracked.id, 'reading-activity');
      expect(tracked.trackingId, 'reading-tracking');
      expect(tracked.name, 'Чтение книг');
      expect(tracked.stepType, 'single');
    },
  );
}
