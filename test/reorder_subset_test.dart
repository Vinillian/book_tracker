import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/reorder.dart';

List<String> names(List<Node> nodes) => [for (final n in nodes) n.name];

void main() {
  Node a() => Node.leaf('a');
  final all = [Node.leaf('a'), Node.leaf('b'), Node.leaf('c'), Node.leaf('d')];

  test('drag down: newIndex is counted before the item is removed', () {
    expect(names(reorderSubset(all, all, 0, 3)), ['b', 'c', 'a', 'd']);
    expect(names(reorderSubset(all, all, 0, 4)), ['b', 'c', 'd', 'a']);
  });

  test('drag up', () {
    expect(names(reorderSubset(all, all, 2, 0)), ['c', 'a', 'b', 'd']);
  });

  test('dropping in place changes nothing', () {
    expect(names(reorderSubset(all, all, 1, 1)), ['a', 'b', 'c', 'd']);
    expect(names(reorderSubset(all, all, 1, 2)), ['a', 'b', 'c', 'd']);
  });

  test('items outside the subset keep their slots', () {
    final x = Node.leaf('a');
    final t1 = Node.leaf('t1')..startMinutes = 9 * 60;
    final y = Node.leaf('b');
    final t2 = Node.leaf('t2')..startMinutes = 15 * 60;
    final z = Node.leaf('c');
    final stored = [x, t1, y, t2, z];
    final noTime = [x, y, z];
    final result = reorderSubset(stored, noTime, 2, 0);
    expect(names(result), ['c', 't1', 'a', 't2', 'b']);
    expect(identical(result[1], t1), isTrue);
    expect(identical(result[3], t2), isTrue);
  });

  test('does not modify its arguments; bad index returns a copy', () {
    final stored = [Node.leaf('a'), Node.leaf('b')];
    final copy = reorderSubset(stored, stored, 5, 0);
    expect(names(copy), ['a', 'b']);
    expect(identical(copy, stored), isFalse);
    reorderSubset(stored, stored, 0, 2);
    expect(names(stored), ['a', 'b']);
  });

  test('nodes with equal names are told apart by identity', () {
    final first = a();
    final second = a();
    final result = reorderSubset([first, second], [first, second], 1, 0);
    expect(identical(result[0], second), isTrue);
    expect(identical(result[1], first), isTrue);
  });
}
