import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/models/standard_task.dart';
import 'package:book_tracker/models/tracked_activity.dart';
import 'package:book_tracker/utils/node_copy.dart';

void main() {
  group('universal supplementary time tracking', () {
    test('old Node JSON loads with time available even without the legacy flag', () {
      final node = Node.fromJson({
        'name': 'Тайчи',
        'children': [],
        'stepType': 'single',
        'totalSteps': 1,
        'completedSteps': 0,
        'timeTrackingEnabled': false,
      });
      expect(node.timeTrackingEnabled, isFalse);
      expect(node.isTimeTrackingEnabled, isTrue);
    });

    test('Node JSON and reset copies keep the time goal, but reset logged minutes', () {
      final node = Node.leaf(
        'Тайчи',
        stepType: 'stepByStep',
        totalSteps: 4,
        targetMinutes: 90,
      )
        ..completedSteps = 2
        ..loggedMinutes = 45;
      final restored = Node.fromJson(node.toJson());
      expect(restored.isTimeTrackingEnabled, isTrue);
      expect(restored.targetMinutes, 90);
      expect(restored.completedLeaves, 2);
      expect(restored.totalLeaves, 4);
      final copy = copyAndReset(restored);
      expect(copy.targetMinutes, 90);
      expect(copy.completedSteps, 0);
      expect(copy.loggedMinutes, 0);
      expect(copy.completedLeaves, 0);
    });

    test('legacy duration Node becomes checkbox + time and retains goal', () {
      final restored = Node.fromJson({
        'name': 'Бег',
        'children': [],
        'stepType': 'duration',
        'targetMinutes': 45,
        'loggedMinutes': 30,
      });
      expect(restored.stepType, 'single');
      expect(restored.targetMinutes, 45);
      expect(restored.loggedMinutes, 30);
      expect(restored.completed, isFalse);
    });

    test('legacy StandardTask duration becomes checkbox + time goal', () {
      final oldTask = StandardTask.fromJson({
        'id': 'old',
        'name': 'Чтение',
        'stepType': 'duration',
        'targetMinutes': 45,
      });
      expect(oldTask.stepType, 'single');
      expect(oldTask.targetMinutes, 45);
      expect(oldTask.toNode().stepType, 'single');
      expect(oldTask.toNode().targetMinutes, 45);
      expect(oldTask.toNode().isTimeTrackingEnabled, isTrue);
    });

    test('StandardTask passes time goals to checkbox and step nodes', () {
      final checkbox = StandardTask(
        name: 'Тайчи',
        stepType: 'single',
        targetMinutes: 30,
      );
      final steps = StandardTask(
        name: 'Чтение',
        stepType: 'stepByStep',
        totalSteps: 5,
        targetMinutes: 60,
      );
      expect(checkbox.toNode().targetMinutes, 30);
      expect(steps.toNode().targetMinutes, 60);
      expect(steps.toNode().stepType, 'stepByStep');
    });

    test('old TrackedActivity duration type is normalized to checkbox row', () {
      final oldActivity = TrackedActivity.fromJson({
        'id': 'old',
        'nodeId': 't',
        'name': 'Чтение',
        'colorValue': 0xFF2196F3,
        'stepType': 'duration',
      });
      expect(oldActivity.stepType, 'single');
      expect(oldActivity.timeTrackingEnabled, isFalse);
    });

    test('TrackedActivity continues to serialize legacy fields safely', () {
      final activity = TrackedActivity(
        nodeId: 't',
        name: 'Тайчи',
        colorValue: 0xFF2196F3,
        stepType: 'single',
      );
      final restored = TrackedActivity.fromJson(activity.toJson());
      expect(restored.stepType, 'single');
    });
  });
}
