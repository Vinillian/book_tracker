import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';

Node single(String name, {bool done = false}) =>
    Node.leaf(name, stepType: 'single')..completed = done;

Node steps(String name, int total, int done) =>
    Node.leaf(name, stepType: 'stepByStep', totalSteps: total)
      ..completedSteps = done;

Node parent(String name, String stepType, List<Node> children) =>
    Node(name: name, stepType: stepType, children: children);

void main() {
  group('leaf progress', () {
    test('single checkbox', () {
      final n = single('a');
      expect(n.totalLeaves, 1);
      expect(n.completedLeaves, 0);
      n.toggle();
      expect(n.completedLeaves, 1);
      n.toggle();
      expect(n.completedLeaves, 0);
    });

    test('steps count as their number', () {
      final n = steps('a', 5, 2);
      expect(n.totalLeaves, 5);
      expect(n.completedLeaves, 2);
    });

    test('toggle does nothing for a stepByStep task', () {
      final n = steps('a', 3, 1);
      n.toggle();
      expect(n.completed, isFalse);
      expect(n.completedLeaves, 1);
    });
  });

  group('folder (pure container)', () {
    test('has no own progress and only sums its children', () {
      final f = parent('f', 'folder', [single('a', done: true), single('b')]);
      expect(f.hasOwnProgress, isFalse);
      expect(f.totalLeaves, 2);
      expect(f.completedLeaves, 1);
      expect(f.nonRoutineLeafCount, 2);
    });

    test('an empty folder counts nothing and is not trackable', () {
      final f = parent('f', 'folder', []);
      expect(f.totalLeaves, 0);
      expect(f.isTrackableTask, isFalse);
    });
  });

  group('task with subtasks keeps its own progress (#111)', () {
    test('single parent: its checkbox counts together with the subtasks', () {
      final p = parent('p', 'single', [single('a'), single('b')]);
      expect(p.hasOwnProgress, isTrue);
      expect(p.totalLeaves, 3);
      expect(p.completedLeaves, 0);
      p.toggle();
      expect(p.completedLeaves, 1);
      p.children.first.toggle();
      expect(p.completedLeaves, 2);
    });

    test('stepByStep parent: its steps count together with the subtasks', () {
      final p = Node(
        name: 'p',
        stepType: 'stepByStep',
        totalSteps: 3,
        completedSteps: 2,
        children: [single('a', done: true)],
      );
      expect(p.totalLeaves, 4);
      expect(p.completedLeaves, 3);
    });

    test('non-routine count includes the parent itself', () {
      final p = parent('p', 'single', [single('a'), single('b')]);
      expect(p.nonRoutineLeafCount, 3);
    });

    test('is trackable with or without subtasks, unless it is a folder', () {
      expect(single('a').isTrackableTask, isTrue);
      expect(parent('p', 'single', [single('a')]).isTrackableTask, isTrue);
      expect(parent('f', 'folder', [single('a')]).isTrackableTask, isFalse);
    });

    test('roots (plans) never have own progress', () {
      final day = Node(
        name: '24.10.2026',
        category: 'planner',
        stepType: 'single',
        children: [single('a', done: true), single('b')],
      );
      expect(day.hasOwnProgress, isFalse);
      expect(day.totalLeaves, 2);
      expect(day.completedLeaves, 1);
    });
  });

  group('excludeFromHistory', () {
    test('an excluded task counts as nothing, also inside a parent', () {
      final skipped = single('skip', done: true)..excludeFromHistory = true;
      final p = parent('f', 'folder', [skipped, single('a')]);
      expect(skipped.totalLeaves, 0);
      expect(skipped.completedLeaves, 0);
      expect(skipped.nonRoutineLeafCount, 0);
      expect(p.totalLeaves, 1);
      expect(p.nonRoutineLeafCount, 1);
    });
  });

  group('deepCopy', () {
    test('is independent of the original but keeps ids', () {
      final original = parent('p', 'folder', [single('a')]);
      final copy = original.deepCopy();
      expect(copy.id, original.id);
      expect(copy.children.first.id, original.children.first.id);
      expect(identical(copy.children.first, original.children.first), isFalse);

      copy.children.first.toggle();
      expect(original.children.first.completed, isFalse);
      copy.children.add(single('b'));
      expect(original.children.length, 1);
    });
  });
}
