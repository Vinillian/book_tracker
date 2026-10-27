import '../models/node.dart';
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
