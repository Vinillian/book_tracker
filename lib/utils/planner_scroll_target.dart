import '../models/node.dart';
import 'plan_date.dart';

/// Returns the index of the most relevant plan:
/// today, otherwise the nearest past day, otherwise the nearest future day.
///
/// [sortedPlans] is the same list that will be displayed by the planner.
/// Plans without a date are ignored.
int? findRelevantPlanIndex(
  List<Node> sortedPlans,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);

  int? todayIndex;
  int? nearestPastIndex;
  int? nearestFutureIndex;

  DateTime? nearestPastDate;
  DateTime? nearestFutureDate;

  for (var i = 0; i < sortedPlans.length; i++) {
    final date = planDateOf(sortedPlans[i]);
    if (date == null) continue;

    if (date == today) {
      todayIndex ??= i;
      continue;
    }

    if (date.isBefore(today)) {
      if (nearestPastDate == null || date.isAfter(nearestPastDate)) {
        nearestPastDate = date;
        nearestPastIndex = i;
      }
    } else {
      if (nearestFutureDate == null || date.isBefore(nearestFutureDate)) {
        nearestFutureDate = date;
        nearestFutureIndex = i;
      }
    }
  }

  return todayIndex ?? nearestPastIndex ?? nearestFutureIndex;
}
