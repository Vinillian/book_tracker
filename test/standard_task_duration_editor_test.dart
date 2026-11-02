import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:book_tracker/models/standard_task.dart';
import 'package:book_tracker/models/tracked_activity.dart';
import 'package:book_tracker/providers/app_state.dart';
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
  await tester.pumpAndSettle();
}

void main() {
  late Directory directory;
  late AppState appState;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('standard_task_editor');
    Hive.init(directory.path);
    registerAppHiveAdapters();
    final boxes = await HiveStartup(
      openBox: <T>(String name) => Hive.openBox<T>(name),
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
    await directory.delete(recursive: true);
  });

  testWidgets('creates a duration standard task with an optional goal',
      (tester) async {
    await _openEditor(
      tester,
      appState,
      StandardTask(name: '', stepType: 'single'),
      isNew: true,
    );

    await tester.enterText(find.byType(TextField).first, 'Чтение');
    await tester.tap(find.text('Длительность'));
    await tester.pumpAndSettle();

    expect(find.text('Цель, минут (необязательно):'), findsOneWidget);
    final targetField = find.byType(TextField).at(1);
    await tester.enterText(targetField, '45');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(appState.standardTasks, hasLength(1));
    expect(appState.standardTasks.single.name, 'Чтение');
    expect(appState.standardTasks.single.stepType, 'duration');
    expect(appState.standardTasks.single.targetMinutes, 45);
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
    await tester.tap(find.text('Длительность'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '60');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

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
