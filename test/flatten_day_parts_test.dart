import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/day_part.dart';
import 'package:book_tracker/utils/flatten_day_parts.dart';

Node folder(String name, List<Node> children) =>
    Node(name: name, stepType: 'folder', children: children);

Node template(List<Node> children) =>
    Node(name: 'Шаблон', category: 'template', children: children);

void main() {
  test('detects day-part folders by name, ignoring case and spaces', () {
    expect(isDayPartFolder(folder('Утро', [])), isTrue);
    expect(isDayPartFolder(folder(' вечер ', [])), isTrue);
    expect(isDayPartFolder(folder('Спорт', [])), isFalse);
    // A task (not a folder) with such a name is not a container.
    expect(isDayPartFolder(Node.leaf('Утро')), isFalse);
    expect(hasDayPartFolders(template([folder('День', [])])), isTrue);
    expect(hasDayPartFolders(template([Node.leaf('a')])), isFalse);
  });

  test('moves tasks to the top level in order and sets default times', () {
    final t = template([
      folder('Утро', [Node.leaf('Зарядка'), Node.leaf('Завтрак')]),
      Node.leaf('Без папки'),
      folder('Вечер', [Node.leaf('Чтение')]),
    ]);
    final flat = flattenDayPartFolders(t);
    expect(
      flat.children.map((c) => c.name).toList(),
      ['Зарядка', 'Завтрак', 'Без папки', 'Чтение'],
    );
    expect(flat.children[0].startMinutes, 8 * 60);
    expect(flat.children[1].startMinutes, 8 * 60);
    expect(flat.children[2].startMinutes, isNull);
    expect(flat.children[3].startMinutes, 19 * 60);
    expect(hasDayPartFolders(flat), isFalse);
  });

  test('default times fall into the matching part of the day', () {
    final flat = flattenDayPartFolders(template([
      folder('Утро', [Node.leaf('a')]),
      folder('День', [Node.leaf('b')]),
      folder('Вечер', [Node.leaf('c')]),
    ]));
    expect(dayPartOf(flat.children[0].startMinutes), DayPart.morning);
    expect(dayPartOf(flat.children[1].startMinutes), DayPart.day);
    expect(dayPartOf(flat.children[2].startMinutes), DayPart.evening);
  });

  test('a task that already has a time keeps it; subtasks stay attached', () {
    final timed = Node.leaf('Йога')..startMinutes = 6 * 60 + 30;
    final parent = Node.leaf('Проект')..children.add(Node.leaf('Подзадача'));
    final flat = flattenDayPartFolders(template([
      folder('Утро', [timed, parent]),
    ]));
    expect(flat.children[0].startMinutes, 6 * 60 + 30);
    expect(flat.children[1].children.single.name, 'Подзадача');
  });

  test('does not touch the original, keeps ids, leaves other folders', () {
    final morning = folder('Утро', [Node.leaf('a')]);
    final other = folder('Спорт', [Node.leaf('b')]);
    final t = template([morning, other]);
    final flat = flattenDayPartFolders(t);
    expect(t.children.length, 2);
    expect(t.children.first.children.first.startMinutes, isNull);
    expect(flat.id, t.id);
    expect(flat.templateTarget, t.templateTarget);
    expect(flat.children.last.name, 'Спорт');
    expect(flat.children.last.children.single.name, 'b');
  });

  test('a template without day-part folders is returned unchanged', () {
    final t = template([Node.leaf('a'), Node.leaf('b')]);
    final flat = flattenDayPartFolders(t);
    expect(flat.children.map((c) => c.name).toList(), ['a', 'b']);
    expect(flat.children.every((c) => c.startMinutes == null), isTrue);
  });
}
