import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/models/standard_task.dart';
import 'package:book_tracker/models/tracked_activity.dart';
import 'package:book_tracker/utils/tracking_choices.dart';

StandardTask standard(
  String name, {
  String stepType = 'single',
  int steps = 1,
  String trackingId = 't',
  bool excluded = false,
}) =>
    StandardTask(
      name: name,
      stepType: stepType,
      totalSteps: steps,
      trackingId: trackingId,
      excludeFromHistory: excluded,
    );

Node planTask(
  String name, {
  String stepType = 'single',
  int steps = 1,
  String trackingId = 't',
  bool excluded = false,
}) =>
    Node.leaf(
      name,
      stepType: stepType,
      totalSteps: steps,
      trackingId: trackingId,
      excludeFromHistory: excluded,
    );

TrackedActivity tracked({
  String nodeId = 'x',
  String name = 'Reading',
  String stepType = 'single',
}) =>
    TrackedActivity(
      id: 'a1',
      nodeId: nodeId,
      name: name,
      colorValue: 0xFF123456,
      stepType: stepType,
      isActive: false,
      isRoutine: true,
      order: 7,
    );

void main() {
  group('trackingChoices', () {
    test('an edited standard task shows its new type, not the old plan copy', () {
      // The task was a checkbox, a plan still holds that copy, then it became
      // a task of 2 steps.
      final choices = trackingChoices(
        standardTasks: [
          standard('Reading', stepType: 'stepByStep', steps: 2, trackingId: 'r'),
        ],
        planLeaves: [planTask('Reading', trackingId: 'r')],
      );
      expect(choices.length, 1);
      expect(choices.single.stepType, 'stepByStep');
      expect(choices.single.totalSteps, 2);
      expect(choices.single.description, 'Пошаговая (2 шагов)');
    });

    test('plan tasks without a standard task are still offered', () {
      final choices = trackingChoices(
        standardTasks: [standard('Bath', trackingId: 'b')],
        planLeaves: [planTask('Tea', trackingId: 'tea')],
      );
      expect(choices.map((c) => c.name), ['Bath', 'Tea']);
    });

    test('the same tracking id is offered once', () {
      final choices = trackingChoices(
        standardTasks: [standard('Bath', trackingId: 'b')],
        planLeaves: [
          planTask('Bath', trackingId: 'b'),
          planTask('Bath again', trackingId: 'b'),
        ],
      );
      expect(choices.length, 1);
      expect(choices.single.name, 'Bath');
    });

    test('tasks excluded from history are left out', () {
      final choices = trackingChoices(
        standardTasks: [standard('Hidden', trackingId: 'h', excluded: true)],
        planLeaves: [planTask('Hidden too', trackingId: 'h2', excluded: true)],
      );
      expect(choices, isEmpty);
    });

    test('ordered by name, case ignored', () {
      final choices = trackingChoices(
        standardTasks: [
          standard('banana', trackingId: '2'),
          standard('Apple', trackingId: '1'),
          standard('cherry', trackingId: '3'),
        ],
        planLeaves: const [],
      );
      expect(choices.map((c) => c.name), ['Apple', 'banana', 'cherry']);
    });

    test('descriptions of the three kinds', () {
      TrackingChoice choice(String type, int steps) => TrackingChoice(
            name: 'n',
            stepType: type,
            totalSteps: steps,
            trackingId: 'id',
          );
      expect(choice('single', 1).description, 'Одиночный чекбокс');
      expect(choice('duration', 1).description, 'Длительность');
      expect(choice('stepByStep', 5).description, 'Пошаговая (5 шагов)');
    });

    test('toNode carries what the tracking needs', () {
      final node = trackingChoices(
        standardTasks: [
          standard('Reading', stepType: 'stepByStep', steps: 2, trackingId: 'r'),
        ],
        planLeaves: const [],
      ).single.toNode();
      expect(node.name, 'Reading');
      expect(node.stepType, 'stepByStep');
      expect(node.totalSteps, 2);
      expect(node.trackingId, 'r');
    });
  });

  group('trackedActivityFollowing', () {
    test('takes the new name and type, keeps everything else', () {
      final updated = trackedActivityFollowing(
        tracked(nodeId: 'r'),
        standard('Reading books', stepType: 'stepByStep', steps: 2, trackingId: 'r'),
        previousTrackingId: 'r',
      )!;
      expect(updated.name, 'Reading books');
      expect(updated.stepType, 'stepByStep');
      expect(updated.id, 'a1');
      expect(updated.nodeId, 'r');
      expect(updated.colorValue, 0xFF123456);
      expect(updated.isActive, isFalse);
      expect(updated.isRoutine, isTrue);
      expect(updated.order, 7);
    });

    test('nothing to do when it already says the same', () {
      expect(
        trackedActivityFollowing(
          tracked(nodeId: 'r', name: 'Reading', stepType: 'single'),
          standard('Reading', trackingId: 'r'),
          previousTrackingId: 'r',
        ),
        isNull,
      );
    });

    test('another task\'s activity is left alone', () {
      expect(
        trackedActivityFollowing(
          tracked(nodeId: 'other'),
          standard('Reading', stepType: 'duration', trackingId: 'r'),
          previousTrackingId: 'r',
        ),
        isNull,
      );
    });

    test('found by the old tracking id when a rename changed it', () {
      final updated = trackedActivityFollowing(
        tracked(nodeId: 'old-id'),
        standard('New name', trackingId: 'new-id'),
        previousTrackingId: 'old-id',
      )!;
      expect(updated.name, 'New name');
      expect(updated.nodeId, 'old-id');
    });
  });
}
