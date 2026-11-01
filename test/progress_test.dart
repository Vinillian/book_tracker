import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/utils/progress.dart';

typedef Item = ({String name, int completed, int total});

Item item(String name, int completed, int total) =>
    (name: name, completed: completed, total: total);

List<String> names(List<Item> items) => [for (final i in items) i.name];

List<Item> ranked(List<Item> items) => sortedByProgress(
      items,
      completed: (i) => i.completed,
      total: (i) => i.total,
    );

void main() {
  group('progressRatio', () {
    test('a share of the total', () {
      expect(progressRatio(1, 4), 0.25);
      expect(progressRatio(4, 4), 1.0);
      expect(progressRatio(0, 5), 0.0);
    });

    test('an empty total is 0, never NaN', () {
      expect(progressRatio(0, 0), 0.0);
      expect(progressRatio(0, 0).isNaN, isFalse);
      expect(progressRatio(3, 0), 0.0);
    });
  });

  group('sortedByProgress', () {
    test('the highest progress first', () {
      final result = ranked([
        item('a', 1, 4), // 0.25
        item('b', 3, 4), // 0.75
        item('c', 2, 4), // 0.5
      ]);
      expect(names(result), ['b', 'c', 'a']);
    });

    test('empty items rank last and do not scramble the rest', () {
      final result = ranked([
        item('empty1', 0, 0),
        item('half', 1, 2),
        item('empty2', 0, 0),
        item('full', 5, 5),
      ]);
      expect(names(result), ['full', 'half', 'empty1', 'empty2']);
    });

    test('equal progress keeps the original order', () {
      final result = ranked([
        item('x', 1, 2),
        item('y', 2, 4),
        item('z', 3, 6),
        item('w', 0, 3),
      ]);
      expect(names(result), ['x', 'y', 'z', 'w']);
    });

    test('the same input always gives the same order', () {
      final input = [
        item('e', 0, 0),
        item('a', 0, 0),
        item('b', 1, 3),
        item('c', 0, 0),
      ];
      final first = names(ranked(input));
      for (var i = 0; i < 5; i++) {
        expect(names(ranked(input)), first);
      }
    });

    test('the input list is not changed, an empty one is fine', () {
      final input = [item('a', 0, 2), item('b', 2, 2)];
      ranked(input);
      expect(names(input), ['a', 'b']);
      expect(ranked(const []), isEmpty);
    });

    test('works with any iterable', () {
      final result = sortedByProgress<(int, int)>(
        {(1, 4), (4, 4)},
        completed: (p) => p.$1,
        total: (p) => p.$2,
      );
      expect(result, [(4, 4), (1, 4)]);
    });
  });
}
