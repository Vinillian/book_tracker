import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/node_copy.dart';
import 'package:book_tracker/utils/template_target.dart';

/// A morning base: timed tasks, one with subtasks, one with steps.
Node base() => Node(
      name: 'Утро',
      category: 'template',
      templateTarget: templateTargetDay,
      children: [
        Node(name: 'Подъем', children: [], startMinutes: 7 * 60),
        Node(name: 'Душ', children: [], startMinutes: 7 * 60 + 10),
        Node(
          name: 'Практики',
          stepType: 'folder',
          startMinutes: 7 * 60 + 20,
          children: [
            Node.leaf('Медитация'),
            Node(name: 'Тайчи', children: [], totalSteps: 2, stepType: 'stepByStep'),
          ],
        ),
      ],
    );

List<String> namesOf(Node n) => [for (final c in n.children) c.name];

Iterable<Node> allNodes(Node n) sync* {
  yield n;
  for (final c in n.children) {
    yield* allNodes(c);
  }
}

void main() {
  group('templateCopy', () {
    test('same tasks, times and subtasks under the new name and purpose', () {
      final source = base();
      final copy = templateCopy(source, name: 'Выходной 1', target: templateTargetOff);
      expect(copy.name, 'Выходной 1');
      expect(copy.category, 'template');
      expect(copy.templateTarget, templateTargetOff);
      expect(namesOf(copy), ['Подъем', 'Душ', 'Практики']);
      expect(copy.children[1].startMinutes, 7 * 60 + 10);
      expect(namesOf(copy.children[2]), ['Медитация', 'Тайчи']);
      expect(copy.children[2].children[1].totalSteps, 2);
      expect(copy.children[2].children[1].stepType, 'stepByStep');
    });

    test('every node gets a new id, so the copy is independent', () {
      final source = base();
      final copy = templateCopy(source, name: 'Копия');
      final sourceIds = allNodes(source).map((n) => n.id).toSet();
      final copyIds = allNodes(copy).map((n) => n.id).toList();
      expect(copyIds.toSet().length, copyIds.length);
      expect(copyIds.any(sourceIds.contains), isFalse);
    });

    test('changing the copy leaves the base alone', () {
      final source = base();
      final copy = templateCopy(source, name: 'Копия');
      copy.children.add(Node.leaf('Лес'));
      copy.children.first.name = 'Подъем в 6';
      expect(namesOf(source), ['Подъем', 'Душ', 'Практики']);
      expect(source.name, 'Утро');
      expect(source.templateTarget, templateTargetDay);
    });

    test('tracking ids stay: copies of one habit are one line in History', () {
      final source = base();
      final copy = templateCopy(source, name: 'Копия');
      expect(copy.children.first.trackingId, source.children.first.trackingId);
    });

    test('progress is reset', () {
      final source = base();
      source.children.first.completed = true;
      source.children[2].children[1].completedSteps = 1;
      source.children[1].loggedMinutes = 10;
      final copy = templateCopy(source, name: 'Копия');
      for (final n in allNodes(copy)) {
        expect(n.completed, isFalse, reason: n.name);
        expect(n.completedSteps, 0, reason: n.name);
        expect(n.loggedMinutes, 0, reason: n.name);
      }
    });

    test('a null purpose means "for any"', () {
      final copy = templateCopy(base(), name: 'Любой', target: null);
      expect(copy.templateTarget, isNull);
      expect(templateTargetLabel(copy.templateTarget), 'Любой');
    });
  });

  group('appendCopiesOfTasks', () {
    test('adds the base tasks after the ones already there', () {
      final target = Node(
        name: 'Выходной 1',
        category: 'template',
        templateTarget: templateTargetOff,
        children: [Node.leaf('Лес')],
      );
      final count = appendCopiesOfTasks(target, base());
      expect(count, 3);
      expect(namesOf(target), ['Лес', 'Подъем', 'Душ', 'Практики']);
      expect(target.children[3].children.length, 2);
      expect(target.children[2].startMinutes, 7 * 60 + 10);
    });

    test('loaded tasks are copies: new ids, base unchanged', () {
      final source = base();
      final target = Node(name: 'T', category: 'template', children: []);
      appendCopiesOfTasks(target, source);
      final sourceIds = [for (final n in allNodes(source)) n.id].toSet();
      expect(allNodes(target).skip(1).any((n) => sourceIds.contains(n.id)),
          isFalse);
      target.children.first.name = 'Другое';
      expect(source.children.first.name, 'Подъем');
      expect(source.children.length, 3);
    });

    test('progress of the base is not loaded', () {
      final source = base();
      source.children.first.completed = true;
      final target = Node(name: 'T', category: 'template', children: []);
      appendCopiesOfTasks(target, source);
      expect(target.children.first.completed, isFalse);
    });

    test('an empty base adds nothing', () {
      final target = Node(
        name: 'T',
        category: 'template',
        children: [Node.leaf('Лес')],
      );
      final empty = Node(name: 'Пусто', category: 'template', children: []);
      expect(appendCopiesOfTasks(target, empty), 0);
      expect(namesOf(target), ['Лес']);
    });

    test('loading a base twice adds the tasks twice, as asked', () {
      final target = Node(name: 'T', category: 'template', children: []);
      final source = base();
      appendCopiesOfTasks(target, source);
      appendCopiesOfTasks(target, source);
      expect(target.children.length, 6);
    });
  });
}
