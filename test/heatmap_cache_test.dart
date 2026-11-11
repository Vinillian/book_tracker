import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:book_tracker/models/history_entry.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/models/note.dart';
import 'package:book_tracker/models/settings.dart';
import 'package:book_tracker/models/standard_task.dart';
import 'package:book_tracker/models/tracked_activity.dart';
import 'package:book_tracker/providers/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('heatmap data is cached until History or tracked activities change',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('heatmap_cache_test_');
    Hive.init(directory.path);
    Hive.registerAdapter(NodeAdapter());
    Hive.registerAdapter(NoteAdapter());
    Hive.registerAdapter(HistoryEntryAdapter());
    Hive.registerAdapter(StandardTaskAdapter());
    Hive.registerAdapter(TrackedActivityAdapter());
    Hive.registerAdapter(AppSettingsAdapter());

    final nodes = await Hive.openBox<Node>('nodes');
    final notes = await Hive.openBox<Note>('notes');
    final history = await Hive.openBox<HistoryEntry>('history');
    final standardTasks = await Hive.openBox<StandardTask>('standard_tasks');
    final tracked = await Hive.openBox<TrackedActivity>('tracked');
    final settings = await Hive.openBox<AppSettings>('settings');

    AppState? appState;
    try {
      const trackingId = 'reading';
      final date = DateTime(2026, 11, 5);
      final activity = TrackedActivity(
        id: 'reading-row',
        nodeId: trackingId,
        name: 'Чтение',
        colorValue: 0xFF2196F3,
        stepType: 'single',
      );

      await tracked.put(activity.id, activity);
      await history.add(
        HistoryEntry(
          id: 'reading-check',
          bookId: 'book',
          nodeId: 'reading-task',
          date: date,
          nodeName: 'Чтение',
          stepType: 'single',
          completed: true,
          trackingId: trackingId,
        ),
      );

      appState = AppState(
        templatesBox: nodes,
        notesBox: notes,
        historyBox: history,
        standardTasksBox: standardTasks,
        trackedActivitiesBox: tracked,
        settingsBox: settings,
      );

      final firstData = appState.heatmapIntensityData;
      expect(firstData[date]?[trackingId], 1);
      expect(identical(firstData, appState.heatmapIntensityData), isTrue);

      // Unrelated AppState notifications must not invalidate the heatmap.
      appState.setThemeMode('light');
      expect(identical(firstData, appState.heatmapIntensityData), isTrue);

      // A new History record invalidates the cached aggregate.
      await history.add(
        HistoryEntry(
          id: 'reading-session',
          bookId: 'book',
          nodeId: 'reading-task',
          date: date,
          nodeName: 'Чтение',
          stepType: 'duration',
          minutes: 20,
          trackingId: trackingId,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final afterHistoryChange = appState.heatmapIntensityData;
      expect(identical(firstData, afterHistoryChange), isFalse);
      expect(afterHistoryChange[date]?[trackingId], 2);

      // Changing the active tracked rows also invalidates the aggregate.
      await tracked.put(
        activity.id,
        TrackedActivity(
          id: activity.id,
          nodeId: activity.nodeId,
          name: activity.name,
          colorValue: activity.colorValue,
          stepType: activity.stepType,
          isActive: false,
          isRoutine: activity.isRoutine,
          order: activity.order,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final afterTrackedChange = appState.heatmapIntensityData;
      expect(identical(afterHistoryChange, afterTrackedChange), isFalse);
      expect(afterTrackedChange, isEmpty);
    } finally {
      appState?.dispose();
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });
}
