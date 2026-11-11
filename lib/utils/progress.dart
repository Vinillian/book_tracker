/// Progress of [completed] out of [total] as a number from 0 to 1; 0 for an
/// empty book or plan (no division by zero, #74).
double progressRatio(int completed, int total) =>
    total > 0 ? completed / total : 0.0;

/// [items] ordered by progress, the highest first. Items with the same
/// progress keep their order, so the result never jumps around; an empty item
/// (total 0) counts as 0.
List<T> sortedByProgress<T>(
  Iterable<T> items, {
  required int Function(T item) completed,
  required int Function(T item) total,
}) {
  final list = items.toList();
  double ratio(int i) => progressRatio(completed(list[i]), total(list[i]));
  final order = List<int>.generate(list.length, (i) => i)
    ..sort((a, b) {
      final byProgress = ratio(b).compareTo(ratio(a));
      return byProgress != 0 ? byProgress : a.compareTo(b);
    });
  return [for (final i in order) list[i]];
}
