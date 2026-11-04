import 'dart:async';
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

Future<void> _closeBoxForTest<T>(Box<T> box, String name) async {
  await box.close().timeout(
    const Duration(seconds: 10),
    onTimeout: () => throw TimeoutException('Timed out closing $name'),
  );
}

/// Windows may briefly lock a freshly closed Hive directory (for example,
/// while another process scans its files). Retry sharing violations only.
Future<void> _deleteTempDirectoryWithRetry(Directory directory) async {
  const maxAttempts = 50;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException catch (error) {
      final isWindowsSharingViolation = error.osError?.errorCode == 32;
      if (!isWindowsSharingViolation || attempt == maxAttempts) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }
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
  OpenedHiveBoxes? openedBoxes;
  WidgetTester? activeTester;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('standard_task_editor');
    Hive.init(directory.path);
    registerAppHiveAdapters();
    openedBoxes = await HiveStartup(
      openBox: <T>(String name) => Hive.openBox<T>(name),
    ).open();
    final boxes = openedBoxes!;
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
    await appState.cancelWatchSubscriptions();
    appState.dispose();

    // Close boxes separately to identify which Hive box blocks shutdown.
    final boxes = openedBoxes;
    if (boxes != null) {
      await _closeBoxForTest(boxes.trackedActivitiesBox, 'trackedActivities');
      await _closeBoxForTest(boxes.standardTasksBox, 'standardTasks');
      await _closeBoxForTest(boxes.notesBox, 'notes');
      await _closeBoxForTest(boxes.historyBox, 'history');
      await _closeBoxForTest(boxes.settingsBox, 'settings');
      await _closeBoxForTest(boxes.templatesBox, 'templates');
    }

    final tester = activeTester;
    if (tester != null) {
      // Use real async time for Windows sharing-violation retries; widget tests
      // otherwise run inside a fake-async zone.
      await tester.runAsync(() => _deleteTempDirectoryWithRetry(directory));
    } else {
      await directory.delete(recursive: true);
    }
    activeTester = null;
  });

  testWidgets('creates a duration standard task with an optional goal',
      (tester) async {
    activeTester = tester;
    await _openEditor(
      tester,
      appState,
      StandardTask(name: '', stepType: 'single'),
      isNew: true,
    );

    await tester.enterText(find.byType(TextField).first, 'Чтение');
    await tester.ensureVisible(find.text('Длительность'));
    await tester.tap(find.text('Длительность'));
    await tester.pump();

    expect(find.text('Цель, минут (необязательно):'), findsOneWidget);
    final targetField = find.byType(TextField).at(1);
    await tester.ensureVisible(targetField);
    await tester.enterText(targetField, '45');
    await tester.tap(find.byIcon(Icons.check));
    await _pumpRouteTransition(tester);

    expect(appState.standardTasks, hasLength(1));
    expect(appState.standardTasks.single.name, 'Чтение');
    expect(appState.standardTasks.single.stepType, 'duration');
    expect(appState.standardTasks.single.targetMinutes, 45);
  }, timeout: const Timeout(Duration(seconds: 60)));


  testWidgets('item-card picker copies duration goal and tracking identity',
      (tester) async {
    activeTester = tester;
    await appState.addStandardTask(
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
    activeTester = tester;
    final task = StandardTask(
      name: 'Чтение',
      stepType: 'single',
      trackingId: 'reading-tracking',
    );
    await appState.addStandardTask(task);
    await appState.addTrackedActivity(
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
