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
      expect(e.completed, isNull);
    });

    test('toJson/fromJson keep minutes', () {
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
      expect(back.completed, true);
    });
  });

  group('HistoryService and heatmap with a real box', () {
    late Directory dir;
    late Box<HistoryEntry> history;
    late Box<TrackedActivity> tracked;

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
      HistoryService.init(history);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('several logs on one day are all kept', () {
      final n = durationNode('Работа');
      final day = DateTime(2026, 10, 25);
      HistoryService.recordDurationLog(
          bookId: 'b', node: n, minutes: 25, targetDate: day);
      HistoryService.recordDurationLog(
          bookId: 'b', node: n, minutes: 30, targetDate: day);
      final entries = HistoryService.getEntriesForDay(day);
      expect(entries.length, 2);
      expect(entries.map((e) => e.minutes).toList()..sort(), [25, 30]);
    });

    test('non-positive minutes are not recorded', () {
      final n = durationNode('Работа');
      expect(HistoryService.recordDurationLog(bookId: 'b', node: n, minutes: 0),
          isNull);
      expect(history.length, 0);
    });

    test('deleteEntryById removes only that log', () {
      final n = durationNode('Работа');
      final day = DateTime(2026, 10, 25);
      final first = HistoryService.recordDurationLog(
          bookId: 'b', node: n, minutes: 25, targetDate: day)!;
      HistoryService.recordDurationLog(
          bookId: 'b', node: n, minutes: 30, targetDate: day);
      expect(HistoryService.deleteEntryById(first), isTrue);
      expect(HistoryService.deleteEntryById(first), isFalse);
      final left = HistoryService.getEntriesForDay(day);
      expect(left.length, 1);
      expect(left.single.minutes, 30);
    });

    test('minutes survive a close and reopen of the box', () async {
      final n = durationNode('Работа');
      HistoryService.recordDurationLog(
          bookId: 'b', node: n, minutes: 45, targetDate: DateTime(2026, 10, 25));
      await Hive.close();
      history = await Hive.openBox<HistoryEntry>('history');
      expect(history.values.single.minutes, 45);
    });

    test('heatmap sums the minutes of a tracked duration task per day',
        () async {
      final n = durationNode('Работа');
      final day = DateTime(2026, 10, 25, 14, 30);
      HistoryService.recordDurationLog(
          bookId: 'b', node: n, minutes: 25, targetDate: day);
      HistoryService.recordDurationLog(
          bookId: 'b', node: n, minutes: 35, targetDate: day);
      await tracked.add(TrackedActivity(
        nodeId: n.trackingId,
        name: n.name,
        colorValue: 0xFF2196F3,
        stepType: 'duration',
      ));
      final data = HeatmapService(history, tracked).getIntensityData();
      expect(data[DateTime(2026, 10, 25)]![n.trackingId], 60);
    });

    test('heatmap ignores untracked tasks', () {
      final n = durationNode('Работа');
      HistoryService.recordDurationLog(
          bookId: 'b', node: n, minutes: 25, targetDate: DateTime(2026, 10, 25));
      final data = HeatmapService(history, tracked).getIntensityData();
      expect(data.isEmpty, isTrue);
    });
  });

  group('formatMinutes', () {
    test('formats minutes and hours', () {
      expect(formatMinutes(0), '0 мин');
      expect(formatMinutes(45), '45 мин');
      expect(formatMinutes(60), '1 ч');
      expect(formatMinutes(90), '1 ч 30 мин');
      expect(formatMinutes(135), '2 ч 15 мин');
    });
  });
}
