import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:book_tracker/models/history_entry.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/models/tracked_activity.dart';
import 'package:book_tracker/services/heatmap_service.dart';
import 'package:book_tracker/services/history_service.dart';
import 'package:book_tracker/utils/format_minutes.dart';

Node durationNode(String name) =>
    Node(name: name, children: [], stepType: 'duration');

void main() {
  group('HistoryEntry minutes', () {
    test('forDuration sets type and minutes', () {
      final e = HistoryEntry.forDuration(
        bookId: 'b',
        nodeId: 'n',
        nodeName: 'Работа',
        minutes: 25,
        trackingId: 't',
      );
      expect(e.stepType, 'duration');
      expect(e.minutes, 25);
      expect(e.startedAt, isNull);
      expect(e.endedAt, isNull);
      expect(e.completed, isNull);
    });

    test('forDuration records an interval ending at the supplied event time', () {
      final end = DateTime(2026, 10, 25, 19);
      final entry = HistoryEntry.forDuration(
        bookId: 'b',
        nodeId: 'n',
        nodeName: 'Работа',
        minutes: 60,
        trackingId: 't',
        date: end,
        startedAt: end.subtract(const Duration(hours: 1)),
        endedAt: end,
        recordedAt: DateTime(2026, 10, 25, 20),
      );
      expect(entry.startedAt, DateTime(2026, 10, 25, 18));
      expect(entry.endedAt, end);
      expect(entry.recordedAt, DateTime(2026, 10, 25, 20));
      expect(entry.date, end);
    });

    test('toJson/fromJson keep minutes and session timestamps', () {
      final e = HistoryEntry.forDuration(
        bookId: 'b',
        nodeId: 'n',
        nodeName: 'Работа',
        minutes: 40,
        trackingId: 't',
      );
      final back = HistoryEntry.fromJson(e.toJson());
      expect(back.minutes, 40);
      expect(back.stepType, 'duration');
      final interval = HistoryEntry.forDuration(
        bookId: 'b',
        nodeId: 'n',
        nodeName: 'Работа',
        minutes: 40,
        trackingId: 't',
        startedAt: DateTime(2026, 10, 1, 9),
        endedAt: DateTime(2026, 10, 1, 9, 40),
        recordedAt: DateTime(2026, 10, 1, 10),
      );
      final intervalBack = HistoryEntry.fromJson(interval.toJson());
      expect(intervalBack.startedAt, interval.startedAt);
      expect(intervalBack.endedAt, interval.endedAt);
      expect(intervalBack.recordedAt, interval.recordedAt);
    });

    test('old json without minutes still loads', () {
      final back = HistoryEntry.fromJson({
        'id': 'x',
        'bookId': 'b',
        'nodeId': 'n',
        'date': DateTime(2026, 10, 1).toIso8601String(),
        'nodeName': 'Тайчи',
        'stepType': 'single',
        'completed': true,
        'completedSteps': null,
        'trackingId': 't',
      });
      expect(back.minutes, isNull);
      expect(back.startedAt, isNull);
      expect(back.endedAt, isNull);
      expect(back.recordedAt, isNull);
      expect(back.progressBefore, isNull);
      expect(back.progressAfter, isNull);
      expect(back.completed, true);
    });
  });

  group('HistoryService and heatmap with a real box', () {
    late Directory dir;
    late Box<HistoryEntry> history;
    late Box<TrackedActivity> tracked;
    late HistoryService historyService;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('duration_history_test');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(HistoryEntryAdapter());
      }
      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(TrackedActivityAdapter());
      }
      history = await Hive.openBox<HistoryEntry>('history');
      tracked = await Hive.openBox<TrackedActivity>('tracked');
      historyService = HistoryService(history);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('several logs on one day are all kept', () {
      final n = durationNode('Работа');
      final day = DateTime(2026, 10, 25);
      historyService.recordDurationLog(
          bookId: 'b', node: n, minutes: 25, targetDate: day);
      historyService.recordDurationLog(
          bookId: 'b', node: n, minutes: 30, targetDate: day);
      final entries = historyService.getEntriesForDay(day);
      expect(entries.length, 2);
      expect(entries.map((e) => e.minutes).toList()..sort(), [25, 30]);
    });

    test('quick-add creates an interval ending at the target time', () {
      final n = durationNode('Работа');
      final end = DateTime(2026, 10, 25, 19);

      historyService.recordDurationLog(
        bookId: 'b',
        node: n,
        minutes: 60,
        targetDate: end,
      );

      final entry = history.values.single;
      expect(entry.startedAt, DateTime(2026, 10, 25, 18));
      expect(entry.endedAt, end);
      expect(entry.date, end);
      expect(entry.recordedAt, isNotNull);
    });

    test('checkbox progress transitions append events and preserve duration sessions', () {
      final n = Node.leaf('Йога', stepType: 'single');
      final day = DateTime(2026, 10, 25);
      historyService.recordDurationLog(
        bookId: 'b', node: n, minutes: 20, targetDate: day,
      );
      historyService.recordUniqueToggle(
        bookId: 'b', node: n, newValue: true, targetDate: day,
      );
      historyService.recordDurationLog(
        bookId: 'b', node: n, minutes: 30, targetDate: day,
      );
      historyService.recordUniqueToggle(
        bookId: 'b', node: n, newValue: false, targetDate: day,
      );

      final entries = historyService.getEntriesForDay(day);
      expect(
        entries.where((e) => e.stepType == 'duration').map((e) => e.minutes).toList()..sort(),
        [20, 30],
      );
      final progress = entries.where((e) => e.stepType == 'single').toList();
      expect(progress.length, 2);
      expect(progress.map((e) => [e.progressBefore, e.progressAfter]).toList(), [
        [0, 1],
        [1, 0],
      ]);
    });

    test('step progress appends each transition and preserves sessions', () {
      final n = Node.leaf('Чтение', stepType: 'stepByStep', totalSteps: 5);
      final day = DateTime(2026, 10, 25);
      historyService.recordDurationLog(
        bookId: 'b', node: n, minutes: 15, targetDate: day,
      );
      historyService.recordUniqueProgress(
        bookId: 'b', node: n, newSteps: 2, targetDate: day,
      );
      historyService.recordDurationLog(
        bookId: 'b', node: n, minutes: 25, targetDate: day,
      );
      historyService.recordUniqueProgress(
        bookId: 'b', node: n, newSteps: 4, previousSteps: 2, targetDate: day,
      );

      final entries = historyService.getEntriesForDay(day);
      expect(entries.where((e) => e.stepType == 'duration').length, 2);
      final progress = entries.where((e) => e.stepType == 'stepByStep').toList();
      expect(progress.length, 2);
      expect(progress.map((e) => [e.progressBefore, e.progressAfter]).toList(), [
        [0, 2],
        [2, 4],
      ]);
    });


    test('progress events retain selected historical date and heatmap uses net change', () async {
      final n = Node.leaf('Чтение', stepType: 'stepByStep', totalSteps: 5);
      final monday = DateTime(2026, 11, 9, 18, 30);
      final tuesday = DateTime(2026, 11, 10, 18, 30);

      historyService.recordUniqueProgress(
        bookId: 'b', node: n, previousSteps: 0, newSteps: 4, targetDate: monday,
      );
      historyService.recordUniqueProgress(
        bookId: 'b', node: n, previousSteps: 4, newSteps: 3, targetDate: monday,
      );
      historyService.recordUniqueProgress(
        bookId: 'b', node: n, previousSteps: 3, newSteps: 2, targetDate: tuesday,
      );

      await tracked.add(TrackedActivity(
        nodeId: n.trackingId,
        name: n.name,
        colorValue: 0xFF2196F3,
        stepType: 'stepByStep',
      ));

      final mondayEntries = historyService.getEntriesForDay(monday);
      expect(mondayEntries.length, 2);
      expect(mondayEntries.every((entry) => entry.date.day == 9), isTrue);
      expect(mondayEntries.every((entry) => entry.recordedAt != null), isTrue);

      final intensity = HeatmapService(history, tracked).getIntensityData();
      expect(intensity[DateTime(2026, 11, 9)]![n.trackingId], 3.0);
      expect(intensity.containsKey(DateTime(2026, 11, 10)), isFalse);
    });

    test('correcting or deleting a progress event updates its historical contribution', () async {
      final n = Node.leaf('Чтение', stepType: 'stepByStep', totalSteps: 5);
      final day = DateTime(2026, 11, 9, 18);
      historyService.recordUniqueProgress(
        bookId: 'b', node: n, previousSteps: 1, newSteps: 4, targetDate: day,
      );
      final entry = history.values.single;

      await tracked.add(TrackedActivity(
        nodeId: n.trackingId,
        name: n.name,
        colorValue: 0xFF2196F3,
        stepType: 'stepByStep',
      ));

      expect(
        historyService.updateProgressEntry(id: entry.id, newProgress: 3),
        isTrue,
      );
      final corrected = history.values.single;
      expect(corrected.progressBefore, 1);
      expect(corrected.progressAfter, 3);
      expect(corrected.date, day);
      expect(corrected.recordedAt, isNotNull);
      expect(
        HeatmapService(history, tracked).getIntensityData()[DateTime(2026, 11, 9)]![n.trackingId],
        2.0,
      );

      expect(historyService.deleteEntryById(entry.id), isTrue);
      expect(history.isEmpty, isTrue);
      expect(HeatmapService(history, tracked).getIntensityData(), isEmpty);
    });

    test('progress transition values survive JSON and Hive serialization', () async {
      final entry = HistoryEntry.forStep(
        bookId: 'b', nodeId: 'n', nodeName: 'Чтение', trackingId: 't',
        previousSteps: 2, completedSteps: 4,
        date: DateTime(2026, 11, 9, 18),
      );
      final jsonCopy = HistoryEntry.fromJson(entry.toJson());
      expect(jsonCopy.progressBefore, 2);
      expect(jsonCopy.progressAfter, 4);

      await history.add(entry);
      await Hive.close();
      history = await Hive.openBox<HistoryEntry>('history');
      tracked = await Hive.openBox<TrackedActivity>('tracked');
      historyService = HistoryService(history);
      expect(history.values.single.progressBefore, 2);
      expect(history.values.single.progressAfter, 4);
    });

    test('quick-add can continue consecutive sessions only within the selected day', () {
      final n = durationNode('Работа');
      final previousDay = DateTime(2026, 10, 24);
      final day = DateTime(2026, 10, 25);
      historyService.recordDurationLog(
        bookId: 'b', node: n, minutes: 30,
        startedAt: DateTime(2026, 10, 24, 22),
        endedAt: DateTime(2026, 10, 24, 22, 30),
      );

      expect(
        historyService.getLatestDurationEntryForNodeOnDay(n.id, day),
        isNull,
      );

      var start = historyService.suggestDurationStart(
        nodeId: n.id,
        day: day,
        plannedStartMinutes: 17 * 60,
        now: DateTime(2026, 10, 25, 19),
      );
      expect(start, DateTime(2026, 10, 25, 17));
      var end = start.add(const Duration(minutes: 30));
      historyService.recordDurationLog(
        bookId: 'b', node: n, minutes: 30,
        startedAt: start, endedAt: end,
      );
      final latest = historyService.getLatestDurationEntryForNodeOnDay(n.id, day)!;
      expect(latest.startedAt, DateTime(2026, 10, 25, 17));
      expect(latest.endedAt, DateTime(2026, 10, 25, 17, 30));

      start = historyService.suggestDurationStart(
        nodeId: n.id,
        day: day,
        plannedStartMinutes: 17 * 60,
      );
      end = start.add(const Duration(minutes: 30));
      historyService.recordDurationLog(
        bookId: 'b', node: n, minutes: 30,
        startedAt: start, endedAt: end,
      );
      expect(
        historyService.getLatestDurationEntryForNodeOnDay(n.id, day)!.endedAt,
        DateTime(2026, 10, 25, 18),
      );
      expect(history.values.length, 3);
      expect(historyService.getEntriesForDay(previousDay).length, 1);
    });

    test('quick-add without a planned start uses the current clock on the selected day', () {
      final n = durationNode('Работа');
      final day = DateTime(2026, 10, 25);
      final suggested = historyService.suggestDurationStart(
        nodeId: n.id,
        day: day,
        now: DateTime(2026, 10, 25, 19, 26),
      );
      expect(suggested, DateTime(2026, 10, 25, 19, 26));
    });

    test('editing one duration session leaves other sessions unchanged', () {
      final n = durationNode('Работа');
      final day = DateTime(2026, 10, 25);
      final editedId = historyService.recordDurationLog(
        bookId: 'b', node: n, minutes: 20, targetDate: day,
      )!;
      historyService.recordDurationLog(
        bookId: 'b', node: n, minutes: 35, targetDate: day,
      );

      expect(
        historyService.updateDurationLog(id: editedId, minutes: 50),
        isTrue,
      );
      expect(
        historyService.getDurationEntriesForNode(n.id).map((e) => e.minutes).toSet(),
        {50, 35},
      );
      final edited = historyService.getDurationEntriesForNode(n.id)
          .singleWhere((e) => e.id == editedId);
      expect(edited.endedAt, day);
      expect(edited.startedAt, day.subtract(const Duration(minutes: 50)));
      expect(
        historyService.updateDurationLog(id: editedId, minutes: 0),
        isFalse,
      );
    });

    test('non-positive minutes are not recorded', () {
      final n = durationNode('Работа');
      expect(historyService.recordDurationLog(bookId: 'b', node: n, minutes: 0),
          isNull);
      expect(history.length, 0);
    });

    test('deleteEntryById removes only one session and preserves task progress', () {
      final n = Node.leaf('Йога', stepType: 'single');
      final day = DateTime(2026, 10, 25);
      historyService.recordUniqueToggle(
        bookId: 'b', node: n, newValue: true, targetDate: day,
      );
      final first = historyService.recordDurationLog(
        bookId: 'b', node: n, minutes: 25, targetDate: day,
      )!;
      historyService.recordDurationLog(
        bookId: 'b', node: n, minutes: 30, targetDate: day,
      );

      expect(historyService.deleteEntryById(first), isTrue);
      expect(historyService.deleteEntryById(first), isFalse);
      final left = historyService.getEntriesForDay(day);
      expect(left.where((e) => e.stepType == 'duration').length, 1);
      expect(left.singleWhere((e) => e.stepType == 'single').completed, isTrue);
      expect(left.singleWhere((e) => e.stepType == 'duration').minutes, 30);
    });

    test('minutes survive a close and reopen of the box', () async {
      final n = durationNode('Работа');
      historyService.recordDurationLog(
          bookId: 'b', node: n, minutes: 45, targetDate: DateTime(2026, 10, 25));
      await Hive.close();
      history = await Hive.openBox<HistoryEntry>('history');
      tracked = await Hive.openBox<TrackedActivity>('tracked');
      historyService = HistoryService(history);
      expect(history.values.single.minutes, 45);
      expect(history.values.single.startedAt,
          DateTime(2026, 10, 25).subtract(const Duration(minutes: 45)));
      expect(history.values.single.endedAt, DateTime(2026, 10, 25));
      expect(history.values.single.recordedAt, isNotNull);
    });

    test('heatmap converts summed duration minutes to fractional 20-minute points',
        () async {
      final n = durationNode('Работа');
      final day20 = DateTime(2026, 10, 20);
      final day40 = DateTime(2026, 10, 21);
      final day60 = DateTime(2026, 10, 22);
      final day5 = DateTime(2026, 10, 23);
      final dayTwoSessions = DateTime(2026, 10, 24);
      final day10 = DateTime(2026, 10, 25);
      final day15 = DateTime(2026, 10, 26);
      final day45 = DateTime(2026, 10, 27);

      historyService.recordDurationLog(
          bookId: 'b', node: n, minutes: 20, targetDate: day20);

      // Separate sessions are summed before converting minutes to points.
      historyService.recordDurationLog(
          bookId: 'b', node: n, minutes: 20, targetDate: day40);
      historyService.recordDurationLog(
          bookId: 'b', node: n, minutes: 20, targetDate: day40);

      historyService.recordDurationLog(
          bookId: 'b', node: n, minutes: 25, targetDate: day60);
      historyService.recordDurationLog(
          bookId: 'b', node: n, minutes: 35, targetDate: day60);

      historyService.recordDurationLog(
          bookId: 'b', node: n, minutes: 5, targetDate: day5);
      historyService.recordDurationLog(
          bookId: 'b', node: n, minutes: 10, targetDate: day10);
      historyService.recordDurationLog(
          bookId: 'b', node: n, minutes: 15, targetDate: day15);
      historyService.recordDurationLog(
          bookId: 'b', node: n, minutes: 45, targetDate: day45);

      historyService.recordDurationLog(
          bookId: 'b', node: n, minutes: 15, targetDate: dayTwoSessions);
      historyService.recordDurationLog(
          bookId: 'b', node: n, minutes: 15, targetDate: dayTwoSessions);

      await tracked.add(TrackedActivity(
        nodeId: n.trackingId,
        name: n.name,
        colorValue: 0xFF2196F3,
        stepType: 'duration',
      ));

      final data = HeatmapService(history, tracked).getIntensityData();
      expect(data[day20]![n.trackingId], 1.0);
      expect(data[day40]![n.trackingId], 2.0);
      expect(data[day60]![n.trackingId], 3.0);
      expect(data[day5]![n.trackingId], 0.25);
      expect(data[day10]![n.trackingId], 0.5);
      expect(data[day15]![n.trackingId], 0.75);
      expect(data[dayTwoSessions]![n.trackingId], 1.5);
      expect(data[day45]![n.trackingId], 2.25);

      // The point conversion is presentation-only; raw history minutes remain.
      final durationEntries =
          history.values.where((entry) => entry.stepType == 'duration');
      final storedMinutes = durationEntries.fold<int>(
        0,
        (total, entry) => total + (entry.minutes ?? 0),
      );
      expect(storedMinutes, 225);
    });

    test('heatmap keeps single and step task intensity semantics unchanged',
        () async {
      final day = DateTime(2026, 10, 25);

      await history.add(HistoryEntry.forSingle(
        bookId: 'b',
        nodeId: 'single-node',
        nodeName: 'Одна отметка',
        completed: true,
        trackingId: 'single-tracking',
        date: day,
      ));
      await history.add(HistoryEntry.forStep(
        bookId: 'b',
        nodeId: 'steps-node',
        nodeName: 'Шаги',
        completedSteps: 4,
        trackingId: 'steps-tracking',
        date: day,
      ));

      await tracked.add(TrackedActivity(
        nodeId: 'single-tracking',
        name: 'Одна отметка',
        colorValue: 0xFF2196F3,
        stepType: 'single',
      ));
      await tracked.add(TrackedActivity(
        nodeId: 'steps-tracking',
        name: 'Шаги',
        colorValue: 0xFF4CAF50,
        stepType: 'stepByStep',
      ));

      final data = HeatmapService(history, tracked).getIntensityData();
      expect(data[day]!['single-tracking'], 1.0);
      expect(data[day]!['steps-tracking'], 4.0);
    });

    test('heatmap combines checkbox progress with independent time points', () async {
      final n = Node.leaf(
        'Тайчи',
        stepType: 'single',
        timeTrackingEnabled: true,
      );
      final day = DateTime(2026, 10, 25);
      await history.add(HistoryEntry.forSingle(
        bookId: 'b',
        nodeId: n.id,
        nodeName: n.name,
        completed: true,
        trackingId: n.trackingId,
        date: day,
      ));
      historyService.recordDurationLog(
        bookId: 'b', node: n, minutes: 30, targetDate: day,
      );
      await tracked.add(TrackedActivity(
        nodeId: n.trackingId,
        name: n.name,
        colorValue: 0xFF2196F3,
        stepType: 'single',
        timeTrackingEnabled: true,
      ));

      final data = HeatmapService(history, tracked).getIntensityData();
      // One checkbox point plus 30 minutes / 20 = 1.5 time points.
      expect(data[day]![n.trackingId], 2.5);
    });

    test('heatmap ignores untracked tasks', () {
      final n = durationNode('Работа');
      historyService.recordDurationLog(
          bookId: 'b', node: n, minutes: 25, targetDate: DateTime(2026, 10, 25));
      final data = HeatmapService(history, tracked).getIntensityData();
      expect(data.isEmpty, isTrue);
    });
  });

  group('historyService.getDurationEntriesForNode', () {
    late Directory dir;
    late Box<HistoryEntry> history;
    late HistoryService historyService;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('duration_entries_test');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(HistoryEntryAdapter());
      }
      history = await Hive.openBox<HistoryEntry>('history');
      historyService = HistoryService(history);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('returns only duration logs of that node, newest first', () {
      final a = durationNode('A');
      final b = durationNode('B');
      historyService.recordDurationLog(
          bookId: 'x', node: a, minutes: 10, targetDate: DateTime(2026, 10, 24, 9));
      historyService.recordDurationLog(
          bookId: 'x', node: a, minutes: 20, targetDate: DateTime(2026, 10, 25, 9));
      historyService.recordDurationLog(
          bookId: 'x', node: b, minutes: 99, targetDate: DateTime(2026, 10, 25, 9));
      historyService.recordUniqueToggle(
          bookId: 'x',
          node: Node(name: 'C', children: [], stepType: 'single'),
          newValue: true);
      final logs = historyService.getDurationEntriesForNode(a.id);
      expect(logs.map((e) => e.minutes).toList(), [20, 10]);
    });
  });

  group('formatDuration', () {
    test('formats minutes and hours', () {
      expect(formatDuration(0), '0 мин');
      expect(formatDuration(45), '45 мин');
      expect(formatDuration(60), '1 ч');
      expect(formatDuration(90), '1 ч 30 мин');
      expect(formatDuration(135), '2 ч 15 мин');
    });
  });
}
