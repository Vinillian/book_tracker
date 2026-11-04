import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/node_copy.dart';

Node legacyDuration(String name, {int? target, int logged = 0}) => Node(
      name: name,
      children: [],
      stepType: 'duration',
      targetMinutes: target,
      loggedMinutes: logged,
    );

void main() {
  group('legacy duration task migration', () {
    test('converts duration to checkbox and preserves an unreached goal', () {
      final task = legacyDuration('Чтение', target: 60, logged: 45);
      expect(task.stepType, 'single');
      expect(task.targetMinutes, 60);
      expect(task.loggedMinutes, 45);
      expect(task.completed, isFalse);
      expect(task.totalLeaves, 1);
      expect(task.completedLeaves, 0);
    });

    test('carries a previously reached goal into checkbox completion once', () {
      final task = legacyDuration('Чтение', target: 60, logged: 60);
      expect(task.stepType, 'single');
      expect(task.completed, isTrue);
      task.loggedMinutes = 0;
      expect(task.completedLeaves, 1);
      task.completed = false;
      task.loggedMinutes = 120;
      expect(task.completedLeaves, 0);
    });

    test('a legacy task without a goal keeps its old done state once time existed', () {
      final task = legacyDuration('Прогулка', logged: 5);
      expect(task.stepType, 'single');
      expect(task.completed, isTrue);
      task.loggedMinutes = 0;
      expect(task.completedLeaves, 1);
    });

    test('time changes never complete a current checkbox task', () {
      final task = Node.leaf('Йога', stepType: 'single', targetMinutes: 60)
        ..loggedMinutes = 120;
      expect(task.totalLeaves, 1);
      expect(task.completedLeaves, 0);
      task.completed = true;
      task.loggedMinutes = 0;
      expect(task.completedLeaves, 1);
    });

    test('time changes never increase step completion', () {
      final task = Node.leaf(
        'Чтение',
        stepType: 'stepByStep',
        totalSteps: 4,
        targetMinutes: 90,
      )
        ..completedSteps = 2
        ..loggedMinutes = 180;
      expect(task.totalLeaves, 4);
      expect(task.completedLeaves, 2);
      task.loggedMinutes = 0;
      expect(task.completedLeaves, 2);
    });

    test('excludeFromHistory still hides progress', () {
      final task = legacyDuration('Отдых', target: 30, logged: 30)
        ..excludeFromHistory = true;
      expect(task.totalLeaves, 0);
      expect(task.completedLeaves, 0);
    });
  });

  group('time goal persistence and copies', () {
    test('time goal and logged minutes survive JSON and deepCopy', () {
      final task = Node.leaf('Работа', targetMinutes: 90)..loggedMinutes = 25;
      final restored = Node.fromJson(task.toJson());
      expect(restored.stepType, 'single');
      expect(restored.targetMinutes, 90);
      expect(restored.loggedMinutes, 25);
      final copy = task.deepCopy();
      expect(copy.targetMinutes, 90);
      expect(copy.loggedMinutes, 25);
    });

    test('copyAndReset clears logged time but keeps the goal', () {
      final original = Node.leaf('Работа', targetMinutes: 60)
        ..loggedMinutes = 45;
      final copy = copyAndReset(original);
      expect(copy.loggedMinutes, 0);
      expect(copy.targetMinutes, 60);
      expect(original.loggedMinutes, 45);
    });

    test('old JSON without time fields still loads', () {
      final json = Node.leaf('Old').toJson()
        ..remove('targetMinutes')
        ..remove('loggedMinutes');
      final task = Node.fromJson(json);
      expect(task.targetMinutes, isNull);
      expect(task.loggedMinutes, 0);
    });

    test('Hive adapter stores checkbox and supplementary time fields', () async {
      final dir = Directory.systemTemp.createTempSync('node_time_goal_');
      Hive.init(dir.path);
      Hive.registerAdapter(NodeAdapter());
      var box = await Hive.openBox<Node>('nodes');
      await box.put('a', Node.leaf('A', targetMinutes: 120)..loggedMinutes = 35);
      await box.put('b', Node.leaf('B'));
      await box.close();
      box = await Hive.openBox<Node>('nodes');
      expect(box.get('a')!.stepType, 'single');
      expect(box.get('a')!.targetMinutes, 120);
      expect(box.get('a')!.loggedMinutes, 35);
      expect(box.get('b')!.targetMinutes, isNull);
      expect(box.get('b')!.loggedMinutes, 0);
      await box.close();
      dir.deleteSync(recursive: true);
    });
  });
}
