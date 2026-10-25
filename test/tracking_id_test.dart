import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/models/tracked_activity.dart';
import 'package:book_tracker/utils/tracking_id.dart';

TrackedActivity activity(String name, String trackingId,
        {bool active = true}) =>
    TrackedActivity(
      nodeId: trackingId,
      name: name,
      colorValue: 0xFF2196F3,
      stepType: 'single',
      isActive: active,
    );

Node leaf(String name, String trackingId) =>
    Node.leaf(name, stepType: 'single', trackingId: trackingId);

void main() {
  group('resolveTrackingId', () {
    test('a tracked activity with the same name wins', () {
      final id = resolveTrackingId(
        'Тайчи',
        tracked: [activity('Тайчи', 'tracked-1')],
        roots: [
          Node(name: 'День', children: [leaf('Тайчи', 'node-1')]),
        ],
        fallback: 'standard-1',
      );
      expect(id, 'tracked-1');
    });

    test('an active activity is preferred over an inactive one', () {
      final id = resolveTrackingId(
        'Тайчи',
        tracked: [
          activity('Тайчи', 'old', active: false),
          activity('Тайчи', 'current'),
        ],
        roots: const [],
        fallback: 'standard-1',
      );
      expect(id, 'current');
    });

    test('an inactive activity is still reused when it is the only one', () {
      final id = resolveTrackingId(
        'Тайчи',
        tracked: [activity('Тайчи', 'old', active: false)],
        roots: const [],
        fallback: 'standard-1',
      );
      expect(id, 'old');
    });

    test('without tracking, a task with the same name is reused (nested too)',
        () {
      final id = resolveTrackingId(
        'Тайчи',
        tracked: const [],
        roots: [
          Node(name: 'Неделя', children: [
            Node(name: 'День', children: [leaf('Тайчи', 'node-1')]),
          ]),
        ],
        fallback: 'standard-1',
      );
      expect(id, 'node-1');
    });

    test('names are compared ignoring case and spaces', () {
      final id = resolveTrackingId(
        '  тайчи ',
        tracked: [activity('Тайчи', 'tracked-1')],
        roots: const [],
        fallback: 'standard-1',
      );
      expect(id, 'tracked-1');
    });

    test('a new habit keeps the fallback', () {
      final id = resolveTrackingId(
        'Йога',
        tracked: [activity('Тайчи', 'tracked-1')],
        roots: [leaf('Чтение', 'node-2')],
        fallback: 'standard-1',
      );
      expect(id, 'standard-1');
    });

    test('an empty name keeps the fallback', () {
      final id = resolveTrackingId(
        '   ',
        tracked: [activity('', 'tracked-1')],
        roots: const [],
        fallback: 'standard-1',
      );
      expect(id, 'standard-1');
    });
  });
}
