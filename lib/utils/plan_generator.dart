import '../models/node.dart';
import 'plan_date.dart';
import 'template_target.dart';
import 'work_schedule.dart';

/// The longest period the plan generator accepts (#145).
const int maxPlanGenerationDays = 366;

/// Calendar days from [from] to [to] inclusive, time of day ignored. Empty when
/// [to] is before [from]. Days are built from year/month/day, so a daylight
/// saving change cannot skip or repeat a day.
List<DateTime> datesInRange(DateTime from, DateTime to) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  final days = <DateTime>[];
  for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
    days.add(d);
  }
  return days;
}

/// One day the generator is going to create.
class PlannedDay {
  final DateTime date;
  final DayType type;
  final Node template;

  const PlannedDay(this.date, this.type, this.template);
}

/// What generating plans for a period would do, computed without changing
/// anything (#145).
class PlanGenerationPreview {
  /// Days to create, in date order.
  final List<PlannedDay> toCreate;

  /// Days that already have a plan: they are never touched.
  final List<DateTime> existing;

  /// Days left out because there is no template for their day type.
  final List<DateTime> withoutTemplate;

  /// The day types that have no template (for a clear message).
  final Set<DayType> missingTemplates;

  const PlanGenerationPreview({
    required this.toCreate,
    required this.existing,
    required this.withoutTemplate,
    required this.missingTemplates,
  });

  int get workCount => toCreate.where((d) => d.type == DayType.work).length;
  int get offCount => toCreate.where((d) => d.type == DayType.off).length;
}

/// Works out which of [dates] get a new plan: a day that already has one is
/// skipped, the type of any other day comes from [schedule], and the plan is
/// made from the first template for that type ([templateForDayType]). A day
/// whose type has no template is left out and reported, nothing is guessed.
PlanGenerationPreview previewPlanGeneration({
  required Iterable<DateTime> dates,
  required WorkSchedule schedule,
  required Iterable<Node> templates,
  required bool Function(DateTime date) hasPlan,
}) {
  final list = templates.toList();
  final templateFor = <DayType, Node?>{
    for (final type in DayType.values) type: templateForDayType(list, type),
  };

  final toCreate = <PlannedDay>[];
  final existing = <DateTime>[];
  final withoutTemplate = <DateTime>[];
  final missing = <DayType>{};

  for (final date in dates) {
    if (hasPlan(date)) {
      existing.add(date);
      continue;
    }
    final type = schedule.dayTypeOf(date);
    final template = templateFor[type];
    if (template == null) {
      withoutTemplate.add(date);
      missing.add(type);
      continue;
    }
    toCreate.add(PlannedDay(date, type, template));
  }

  return PlanGenerationPreview(
    toCreate: toCreate,
    existing: existing,
    withoutTemplate: withoutTemplate,
    missingTemplates: missing,
  );
}

/// True if anything in [node] was done: a ticked task, finished steps or
/// logged time, at any depth (#163).
bool dayHasProgress(Node node) {
  if (node.completed || node.completedSteps > 0 || node.loggedMinutes > 0) {
    return true;
  }
  return node.children.any(dayHasProgress);
}

/// What deleting the plans of a period would do, computed without changing
/// anything (#163).
class PlanDeletionPreview {
  /// Days to delete, in date order.
  final List<Node> toDelete;

  /// Days left alone because something is done in them.
  final List<Node> keptWithProgress;

  /// How many of [toDelete] still have something done (only when the
  /// "keep days with progress" option is off).
  final int deletedWithProgress;

  const PlanDeletionPreview({
    required this.toDelete,
    required this.keptWithProgress,
    required this.deletedWithProgress,
  });
}

/// Picks the plans of [plans] whose date is one of [dates]. With
/// [keepDaysWithProgress] a day where something is done is not deleted.
/// Plans without a date are never matched.
PlanDeletionPreview previewPlanDeletion({
  required Iterable<DateTime> dates,
  required Iterable<Node> plans,
  required bool keepDaysWithProgress,
}) {
  final wanted = dates.toSet();
  final inRange = <(DateTime, Node)>[];
  for (final plan in plans) {
    final date = planDateOf(plan);
    if (date != null && wanted.contains(date)) inRange.add((date, plan));
  }
  inRange.sort((a, b) => a.$1.compareTo(b.$1));

  final toDelete = <Node>[];
  final kept = <Node>[];
  var deletedWithProgress = 0;
  for (final (_, plan) in inRange) {
    final done = dayHasProgress(plan);
    if (done && keepDaysWithProgress) {
      kept.add(plan);
    } else {
      toDelete.add(plan);
      if (done) deletedWithProgress++;
    }
  }
  return PlanDeletionPreview(
    toDelete: toDelete,
    keptWithProgress: kept,
    deletedWithProgress: deletedWithProgress,
  );
}
