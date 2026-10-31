import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/models/standard_task.dart';
import 'package:book_tracker/models/tracked_activity.dart';
import 'package:book_tracker/utils/tracking_choices.dart';
import 'package:book_tracker/utils/tracking_id.dart';

StandardTask standard(String name, String trackingId) =>
    StandardTask(name: name, stepType: 'single', trackingId: trackingId);

TrackedActivity tracked(String nodeId, String name) => TrackedActivity(
      id: 'a-$nodeId',
      nodeId: nodeId,
      name: name,
      colorValue: 0xFF123456,
      stepType: 'single',
      isActive: true,
      isRoutine: true,
      order: 0,
    );

Node planTask(String name, String trackingId) =>
    Node.leaf(name, trackingId: trackingId);

Node plan(List<Node> tasks) =>
    Node(name: '01.11.2026', children: tasks, category: 'planner');

/// What saving a standard task does (standard_tasks_screen.dart): the one rule
/// with the task's own tracking id as the fallback.
String savedTrackingId(
  StandardTask edited,
  String newName, {
  List<TrackedActivity> trackedActivities = const [],
  List<Node> roots = const [],
}) =>
    resolveTrackingId(
      newName,
      tracked: trackedActivities,
      roots: roots,
      fallback: edited.trackingId,
    );

void main() {
  group('saving a standard task', () {
    test('a rename to a fresh name keeps the task\'s own id', () {
      final task = standard('Чтение', 'X');
      expect(savedTrackingId(task, 'Чтение книг'), 'X');
    });

    test('a rename keeps the id the plan tasks of the old name carry', () {
      final task = standard('Чтение', 'X');
      final roots = [plan([planTask('Чтение', 'X')])];
      expect(savedTrackingId(task, 'Чтение книг', roots: roots), 'X');
    });

    test('a new standard task nobody uses keeps its own fresh id', () {
      expect(savedTrackingId(standard('', 'fresh'), 'Йога'), 'fresh');
    });

    test('a rename to the name of another tracked habit joins that habit', () {
      final task = standard('Чтение', 'X');
      expect(
        savedTrackingId(
          task,
          'Медитация',
          trackedActivities: [tracked('Z', 'Медитация')],
        ),
        'Z',
      );
    });

    test('a rename to the name of an existing plan task joins that task', () {
      final task = standard('Чтение', 'X');
      final roots = [plan([planTask('Йога', 'Y')])];
      expect(savedTrackingId(task, 'Йога', roots: roots), 'Y');
    });

    test('an edit without a rename keeps the id too', () {
      final task = standard('Чтение', 'X');
      final roots = [plan([planTask('Чтение', 'X')])];
      expect(savedTrackingId(task, 'Чтение', roots: roots), 'X');
      expect(savedTrackingId(task, 'Чтение'), 'X');
    });
  });

  group('after a rename the habit stays on its line', () {
    test('the tracked activity follows and adding the task finds the same id',
        () {
      final renamed = standard('Чтение книг', 'X');
      final updated = trackedActivityFollowing(
        tracked('X', 'Чтение'),
        renamed,
        previousTrackingId: 'X',
      )!;
      expect(updated.name, 'Чтение книг');
      expect(updated.nodeId, 'X');

      // Adding the renamed task to a day (item card or quick picker):
      expect(
        resolveTrackingId(
          'Чтение книг',
          tracked: [updated],
          roots: const [],
          fallback: renamed.trackingId,
        ),
        'X',
      );
    });

    test('even data saved by the old code (the task got another id) joins',
        () {
      // The standard task was renamed and got a fresh id 'Y'; its tracked
      // activity follows the name but keeps 'X'. Adding the task finds 'X'.
      final renamed = standard('Чтение книг', 'Y');
      final updated = trackedActivityFollowing(
        tracked('X', 'Чтение'),
        renamed,
        previousTrackingId: 'X',
      )!;
      expect(
        resolveTrackingId(
          'Чтение книг',
          tracked: [updated],
          roots: const [],
          fallback: renamed.trackingId,
        ),
        'X',
      );
    });

    test('the heatmap picker offers the renamed task once, not as a new line',
        () {
      final renamed = standard('Чтение книг', 'X');
      final choices = trackingChoices(
        standardTasks: [renamed],
        planLeaves: [planTask('Чтение', 'X')],
      );
      expect(choices.length, 1);
      expect(choices.single.name, 'Чтение книг');
    });
  });
}
