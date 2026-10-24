import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/node_copy.dart';

Node duration(String name, {int? target, int logged = 0}) => Node(
      name: name,
      children: [],
      stepType: 'duration',
      targetMinutes: target,
      loggedMinutes: logged,
    );

void main() {
  group('duration progress', () {
    test('with a goal: one unit, done when the goal is reached', () {
      final n = duration('Работа', target: 60, logged: 59);
      expect(n.totalLeaves, 1);
      expect(n.completedLeaves, 0);
      n.loggedMinutes = 60;
      expect(n.completedLeaves, 1);
      n.loggedMinutes = 90;
      expect(n.completedLeaves, 1);
    });

    test('without a goal: done once any time is logged', () {
      final n = duration('Прогулка');
      expect(n.completedLeaves, 0);
      n.loggedMinutes = 5;
      expect(n.completedLeaves, 1);
      final zeroGoal = duration('Прогулка', target: 0, logged: 5);
      expect(zeroGoal.completedLeaves, 1);
    });

    test('excludeFromHistory still hides it', () {
      final n = duration('Отдых', target: 30, logged: 30)
        ..excludeFromHistory = true;
      expect(n.totalLeaves, 0);
      expect(n.completedLeaves, 0);
    });

    test('toggle does nothing for a duration task', () {
      final n = duration('Работа', target: 60);
      n.toggle();
      expect(n.completed, isFalse);
      expect(n.loggedMinutes, 0);
    });

    test('counts together with subtasks of the parent', () {
      final sub = Node.leaf('Подзадача')..completed = true;
      final parent = Node(
        name: 'Работа',
        stepType: 'duration',
        targetMinutes: 60,
        loggedMinutes: 60,
        children: [sub],
      );
      expect(parent.totalLeaves, 2);
      expect(parent.completedLeaves, 2);
    });

    test('step-by-step and single tasks are unchanged', () {
      final single = Node.leaf('a')..completed = true;
      final steps = Node.leaf('b', stepType: 'stepByStep', totalSteps: 4)
        ..completedSteps = 3;
      final folder = Node(name: 'f', stepType: 'folder', children: []);
      expect([single.totalLeaves, single.completedLeaves], [1, 1]);
      expect([steps.totalLeaves, steps.completedLeaves], [4, 3]);
      expect([folder.totalLeaves, folder.completedLeaves], [0, 0]);
    });
  });

  group('duration fields', () {
    test('survive toJson / fromJson and deepCopy', () {
      final n = duration('Работа', target: 90, logged: 25);
      final fromJson = Node.fromJson(n.toJson());
      expect(fromJson.stepType, 'duration');
      expect(fromJson.targetMinutes, 90);
      expect(fromJson.loggedMinutes, 25);
      final copy = n.deepCopy();
      expect(copy.targetMinutes, 90);
      expect(copy.loggedMinutes, 25);
    });

    test('old JSON without the fields imports with no goal and 0 logged', () {
      final json = Node.leaf('Old').toJson()
        ..remove('targetMinutes')
        ..remove('loggedMinutes');
      final n = Node.fromJson(json);
      expect(n.targetMinutes, isNull);
      expect(n.loggedMinutes, 0);
    });

    test('copyAndReset resets logged time and keeps the goal', () {
      final original = duration('Работа', target: 60, logged: 45);
      final copy = copyAndReset(original);
      expect(copy.loggedMinutes, 0);
      expect(copy.targetMinutes, 60);
      expect(original.loggedMinutes, 45);
    });

    test('Hive adapter stores and restores them', () async {
      final dir = Directory.systemTemp.createTempSync('node_duration_');
      Hive.init(dir.path);
      Hive.registerAdapter(NodeAdapter());
      var box = await Hive.openBox<Node>('nodes');
      await box.put('a', duration('A', target: 120, logged: 35));
      await box.put('b', Node.leaf('B'));
      await box.close();
      box = await Hive.openBox<Node>('nodes');
      expect(box.get('a')!.stepType, 'duration');
      expect(box.get('a')!.targetMinutes, 120);
      expect(box.get('a')!.loggedMinutes, 35);
      expect(box.get('b')!.targetMinutes, isNull);
      expect(box.get('b')!.loggedMinutes, 0);
      await box.close();
      dir.deleteSync(recursive: true);
    });
  });
}
