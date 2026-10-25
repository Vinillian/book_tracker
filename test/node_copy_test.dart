import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/node_copy.dart';

Set<String> idsOf(Node n) => {n.id, for (final c in n.children) ...idsOf(c)};

void main() {
  Node sample() {
    final done = Node.leaf('Зарядка', stepType: 'single')
      ..completed = true
      ..startMinutes = 7 * 60;
    final reading = Node.leaf('Чтение', stepType: 'stepByStep', totalSteps: 4)
      ..completedSteps = 3;
    final sub = Node.leaf('Подзадача')..completed = true;
    final parent = Node(
      name: 'Родитель',
      stepType: 'single',
      completed: true,
      children: [sub],
    );
    return Node(
      name: 'День',
      category: 'planner',
      stepType: 'folder',
      children: [done, reading, parent],
    );
  }

  test('every node gets a new id, the original is untouched', () {
    final original = sample();
    final before = idsOf(original);
    final copy = copyAndReset(original);
    expect(idsOf(copy).intersection(before), isEmpty);
    expect(idsOf(copy).length, before.length);
    expect(idsOf(original), before);
  });

  test('progress is reset in the copy only, also in subtasks', () {
    final original = sample();
    final copy = copyAndReset(original);
    expect(copy.completedLeaves, 0);
    expect(copy.children[1].completedSteps, 0);
    expect(copy.children[2].completed, isFalse);
    expect(copy.children[2].children.first.completed, isFalse);

    expect(original.children[0].completed, isTrue);
    expect(original.children[1].completedSteps, 3);
    expect(original.children[2].children.first.completed, isTrue);
  });

  test('trackingId, name, steps, start time and structure are kept', () {
    final original = sample();
    final copy = copyAndReset(original);
    expect(copy.name, original.name);
    expect(copy.children.length, 3);
    for (var i = 0; i < 3; i++) {
      expect(copy.children[i].trackingId, original.children[i].trackingId);
      expect(copy.children[i].name, original.children[i].name);
    }
    expect(copy.children[0].startMinutes, 420);
    expect(copy.children[1].totalSteps, 4);
    expect(
      copy.children[2].children.first.trackingId,
      original.children[2].children.first.trackingId,
    );
  });

  test('the copy is independent of the original', () {
    final original = sample();
    final copy = copyAndReset(original);
    copy.children.removeAt(0);
    copy.children.last.children.add(Node.leaf('Новая'));
    expect(original.children.length, 3);
    expect(original.children.last.children.length, 1);
  });
}
