import 'dart:io';

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
  print('[duration-editor] openEditor: before pumpWidget');
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

  print('[duration-editor] openEditor: after pumpWidget');
  await tester.tap(find.text('Открыть редактор'));
  print('[duration-editor] openEditor: after tap');
  await _pumpRouteTransition(tester);
  print('[duration-editor] openEditor: after route pump');
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  // Avoid waiting for the blinking cursor of an autofocus TextField.
  // Material route transitions finish within 500 ms.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  late Directory directory;
  late AppState appState;

  setUp(() async {
    print('[duration-editor] setUp: start');
    directory = await Directory.systemTemp.createTemp('standard_task_editor');
    Hive.init(directory.path);
    registerAppHiveAdapters();
    print('[duration-editor] setUp: adapters registered');
    final boxes = await HiveStartup(
      openBox: <T>(String name) => Hive.openBox<T>(name),
    ).open();
    print('[duration-editor] setUp: boxes opened');
    appState = AppState(
      templatesBox: boxes.templatesBox,
      notesBox: boxes.notesBox,
      historyBox: boxes.historyBox,
      standardTasksBox: boxes.standardTasksBox,
      trackedActivitiesBox: boxes.trackedActivitiesBox,
      settingsBox: boxes.settingsBox,
    );
    print('[duration-editor] setUp: complete');
  });

  tearDown(() async {
    print('[duration-editor] tearDown: start');
    await appState.cancelWatchSubscriptions();
    print('[duration-editor] tearDown: watch subscriptions cancelled');
    appState.dispose();
    print('[duration-editor] tearDown: appState disposed');
    await Hive.close();
    print('[duration-editor] tearDown: Hive closed');
    await directory.delete(recursive: true);
    print('[duration-editor] tearDown: complete');
  });

  testWidgets('creates a duration standard task with an optional goal',
      (tester) async {
    print('[duration-editor] test: before openEditor');
    await _openEditor(
      tester,
      appState,
      StandardTask(name: '', stepType: 'single'),
      isNew: true,
    );

    print('[duration-editor] test: editor opened');
    await tester.enterText(find.byType(TextField).first, 'Чтение');
    print('[duration-editor] test: name entered');
    await tester.ensureVisible(find.text('Длительность'));
    print('[duration-editor] test: duration visible');
    await tester.tap(find.text('Длительность'));
    print('[duration-editor] test: duration tapped');
    await tester.pump();
    print('[duration-editor] test: duration pumped');

    expect(find.text('Цель, минут (необязательно):'), findsOneWidget);
    print('[duration-editor] test: goal label found');
    final targetField = find.byType(TextField).at(1);
    await tester.ensureVisible(targetField);
    print('[duration-editor] test: goal field visible');
    await tester.enterText(targetField, '45');
    print('[duration-editor] test: goal entered');
    await tester.tap(find.byIcon(Icons.check));
    print('[duration-editor] test: save tapped');
    await _pumpRouteTransition(tester);
    print('[duration-editor] test: route popped');

    expect(appState.standardTasks, hasLength(1));
    expect(appState.standardTasks.single.name, 'Чтение');
    expect(appState.standardTasks.single.stepType, 'duration');
    expect(appState.standardTasks.single.targetMinutes, 45);
  }, timeout: const Timeout(Duration(seconds: 60)));


  testWidgets('item-card picker copies duration goal and tracking identity',
      (tester) async {
    appState.addStandardTask(
      StandardTask(
        name: 'Бег',
        stepType: 'duration',
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
    expect(createdNode!.stepType, 'duration');
    expect(createdNode!.targetMinutes, 45);
    expect(createdNode!.trackingId, 'running-standard-task');
  });

  testWidgets('editing duration task preserves tracking id and updates tracked activity',
      (tester) async {
    final task = StandardTask(
      name: 'Чтение',
      stepType: 'single',
      trackingId: 'reading-tracking',
    );
    appState.addStandardTask(task);
    appState.addTrackedActivity(
      TrackedActivity(
        id: 'reading-activity',
        nodeId: 'reading-tracking',
        name: 'Чтение',
        colorValue: 0xFF2196F3,
        stepType: 'single',
      ),
    );

    await _openEditor(tester, appState, task, isNew: false);
    await tester.enterText(find.byType(TextField).first, 'Чтение книг');
    await tester.ensureVisible(find.text('Длительность'));
    await tester.tap(find.text('Длительность'));
    await tester.pump();
    final targetField = find.byType(TextField).at(1);
    await tester.ensureVisible(targetField);
    await tester.enterText(targetField, '60');
    await tester.tap(find.byIcon(Icons.check));
    await _pumpRouteTransition(tester);

    final updatedTask = appState.standardTasks.single;
    final tracked = appState.trackedActivities.single;
    expect(updatedTask.name, 'Чтение книг');
    expect(updatedTask.stepType, 'duration');
    expect(updatedTask.targetMinutes, 60);
    expect(updatedTask.trackingId, 'reading-tracking');
    expect(tracked.id, 'reading-activity');
    expect(tracked.nodeId, 'reading-tracking');
    expect(tracked.name, 'Чтение книг');
    expect(tracked.stepType, 'duration');
  });
}
