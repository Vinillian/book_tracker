import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/plan_task_order.dart';

void main() {
  Node task(String name, [int? minutes]) =>
      Node.leaf(name)..startMinutes = minutes;

  test('timed tasks are chronological and equal times are stable', () {
    final early = task('early', 8 * 60);
    final firstAtNine = task('first at nine', 9 * 60);
    final untimed = task('untimed');
    final secondAtNine = task('second at nine', 9 * 60);
    final late = task('late', 18 * 60);

    final groups = groupPlanTasks([
      late,
      firstAtNine,
      untimed,
      secondAtNine,
      early,
    ]);

    expect(groups.timed, [early, firstAtNine, secondAtNine, late]);
    expect(groups.untimed, [untimed]);
    expect(groups.displayOrder, [
      early,
      firstAtNine,
      secondAtNine,
      late,
      untimed,
    ]);
  });

  test('grouping does not mutate the stored list', () {
    final late = task('late', 18 * 60);
    final untimed = task('untimed');
    final early = task('early', 8 * 60);
    final stored = [late, untimed, early];

    groupPlanTasks(stored);

    expect(stored, [late, untimed, early]);
  });

  test('reordering untimed tasks preserves timed task slots', () {
    final a = task('a');
    final timedOne = task('timed one', 9 * 60);
    final b = task('b');
    final timedTwo = task('timed two', 15 * 60);
    final c = task('c');
    final stored = [a, timedOne, b, timedTwo, c];

    final reordered = reorderUntimedPlanTasks(stored, 2, 0);

    expect(reordered, [c, timedOne, a, timedTwo, b]);
    expect(identical(reordered[1], timedOne), isTrue);
    expect(identical(reordered[3], timedTwo), isTrue);
    expect(stored, [a, timedOne, b, timedTwo, c]);
  });

  test('clearing a time returns a task to untimed stored order', () {
    final first = task('first');
    final moved = task('moved', 10 * 60);
    final last = task('last');
    final stored = [first, moved, last];

    moved.startMinutes = null;
    final groups = groupPlanTasks(stored);

    expect(groups.timed, isEmpty);
    expect(groups.untimed, [first, moved, last]);
  });
}
