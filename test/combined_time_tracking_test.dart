import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/models/standard_task.dart';
import 'package:book_tracker/models/tracked_activity.dart';
import 'package:book_tracker/utils/node_copy.dart';

void main() {
  group('independent time tracking model compatibility', () {
    test('old Node JSON defaults the option to false', () {
      final node = Node.fromJson({
        'name': 'Тайчи',
        'children': [],
        'stepType': 'single',
        'totalSteps': 1,
        'completedSteps': 0,
      });
      expect(node.timeTrackingEnabled, isFalse);
      expect(node.isTimeTrackingEnabled, isFalse);
    });

    test('Node JSON and reset copies keep the option without counting time as progress', () {
      final node = Node.leaf(
        'Тайчи',
        stepType: 'stepByStep',
        totalSteps: 4,
        timeTrackingEnabled: true,
      )
        ..completedSteps = 2
        ..loggedMinutes = 45;
      final restored = Node.fromJson(node.toJson());
      expect(restored.timeTrackingEnabled, isTrue);
      expect(restored.isTimeTrackingEnabled, isTrue);
      expect(restored.completedLeaves, 2);
      expect(restored.totalLeaves, 4);
      final copy = copyAndReset(restored);
      expect(copy.timeTrackingEnabled, isTrue);
      expect(copy.completedSteps, 0);
      expect(copy.loggedMinutes, 0);
    });

    test('old StandardTask JSON defaults to false and enabled tasks create enabled nodes', () {
      final oldTask = StandardTask.fromJson({
        'id': 'old',
        'name': 'Чтение',
        'stepType': 'single',
      });
      expect(oldTask.timeTrackingEnabled, isFalse);
      final task = StandardTask(
        name: 'Тайчи',
        stepType: 'single',
        timeTrackingEnabled: true,
      );
      final restored = StandardTask.fromJson(task.toJson());
      expect(restored.timeTrackingEnabled, isTrue);
      expect(restored.toNode().timeTrackingEnabled, isTrue);
    });

    test('TrackedActivity JSON preserves heatmap scale and old data defaults false', () {
      final oldActivity = TrackedActivity.fromJson({
        'id': 'old',
        'nodeId': 't',
        'name': 'Чтение',
        'colorValue': 0xFF2196F3,
        'stepType': 'single',
      });
      expect(oldActivity.timeTrackingEnabled, isFalse);
      final activity = TrackedActivity(
        nodeId: 't',
        name: 'Тайчи',
        colorValue: 0xFF2196F3,
        stepType: 'single',
        timeTrackingEnabled: true,
      );
      final restored = TrackedActivity.fromJson(activity.toJson());
      expect(restored.timeTrackingEnabled, isTrue);
    });
  });
}
