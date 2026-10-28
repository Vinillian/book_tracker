import 'dart:convert';
import 'dart:math' as math;

/// Whether a day is a work day or a day off according to the work schedule.
enum DayType { work, off }

String dayTypeLabel(DayType type) =>
    type == DayType.work ? 'Рабочий день' : 'Выходной';

/// A repeating work schedule: [workDays] work days, then [offDays] days off,
/// and so on (2 / 2 is "два через два").
///
/// [anchor] is the first day of a block: of a work block if [anchorIsWork],
/// otherwise of a day-off block. The type of any date is computed from the rule
/// (#144); the only per-date data are the [overrides]: days whose type was set
/// by hand (a holiday, a swapped shift).
class WorkSchedule {
  final int workDays;
  final int offDays;
  final DateTime anchor;
  final bool anchorIsWork;

  /// Days whose type was set by hand; they win over the rule. Keys are dates
  /// without a time of day. Never changed in place: [withDayType] makes a copy.
  final Map<DateTime, DayType> overrides;

  WorkSchedule({
    required this.workDays,
    required this.offDays,
    required DateTime anchor,
    this.anchorIsWork = false,
    Map<DateTime, DayType> overrides = const {},
  })  : assert(workDays >= 1 && offDays >= 1),
        anchor = DateTime(anchor.year, anchor.month, anchor.day),
        overrides = Map<DateTime, DayType>.unmodifiable({
          for (final e in overrides.entries) _dateOnly(e.key): e.value,
        });

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  int get cycleLength => workDays + offDays;

  String get summary => 'Рабочих дней: $workDays, выходных: $offDays';

  /// Calendar days from the anchor to [date], negative before the anchor.
  /// Counted in UTC so daylight saving time cannot shift the result.
  int _daysFromAnchor(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day)
          .difference(DateTime.utc(anchor.year, anchor.month, anchor.day))
          .inDays;

  /// Position of [date] inside the cycle, 0 = the anchor day.
  int _positionOf(DateTime date) =>
      _daysFromAnchor(date) % cycleLength; // Dart's % is never negative here

  /// The type of [date] by the rule alone, ignoring [overrides].
  DayType baseDayTypeOf(DateTime date) {
    final firstBlock = anchorIsWork ? workDays : offDays;
    final firstType = anchorIsWork ? DayType.work : DayType.off;
    final secondType = anchorIsWork ? DayType.off : DayType.work;
    return _positionOf(date) < firstBlock ? firstType : secondType;
  }

  /// The type of [date]: set by hand if it was, otherwise by the rule.
  DayType dayTypeOf(DateTime date) =>
      overrides[_dateOnly(date)] ?? baseDayTypeOf(date);

  /// True if the type of [date] was set by hand.
  bool isOverridden(DateTime date) => overrides.containsKey(_dateOnly(date));

  /// A copy where [date] has the type [type] by hand; null brings the rule
  /// back. An override that says the same as the rule is not stored.
  WorkSchedule withDayType(DateTime date, DayType? type) {
    final key = _dateOnly(date);
    final next = {...overrides};
    if (type == null || type == baseDayTypeOf(key)) {
      next.remove(key);
    } else {
      next[key] = type;
    }
    return copyWith(overrides: next);
  }

  /// A copy with other rule values and/or other overrides.
  WorkSchedule copyWith({
    int? workDays,
    int? offDays,
    DateTime? anchor,
    bool? anchorIsWork,
    Map<DateTime, DayType>? overrides,
  }) =>
      WorkSchedule(
        workDays: workDays ?? this.workDays,
        offDays: offDays ?? this.offDays,
        anchor: anchor ?? this.anchor,
        anchorIsWork: anchorIsWork ?? this.anchorIsWork,
        overrides: overrides ?? this.overrides,
      );

  /// Days off by the rule in [anchor, date), or minus those in [date, anchor)
  /// when [date] is before the anchor.
  int _baseOffDaysBefore(DateTime date) {
    final days = _daysFromAnchor(date);
    final position = days % cycleLength;
    final cycle = (days - position) ~/ cycleLength;
    final inBlock = anchorIsWork
        ? math.max(0, position - workDays)
        : math.min(position, offDays);
    return cycle * offDays + inBlock;
  }

  /// What the overrides add to the count of days off in [anchor, date) (minus
  /// the same for [date, anchor) before the anchor): +1 for a work day made a
  /// day off, -1 for a day off made a work day.
  int _overrideShiftBefore(DateTime date) {
    var shift = 0;
    for (final e in overrides.entries) {
      final day = e.key;
      final delta = e.value == baseDayTypeOf(day)
          ? 0
          : (e.value == DayType.off ? 1 : -1);
      if (delta == 0) continue;
      if (!date.isBefore(anchor)) {
        if (!day.isBefore(anchor) && day.isBefore(date)) shift += delta;
      } else {
        if (!day.isBefore(date) && day.isBefore(anchor)) shift -= delta;
      }
    }
    return shift;
  }

  /// The number of a day off among all the days off, counted from the anchor:
  /// the number of days off between the anchor and [date] (negative before the
  /// anchor), so the first day off at or after the anchor is 0, the next 1, and
  /// so on. Days set by hand count as they are: a day made a day off takes its
  /// place in the sequence, a day made a work day drops out of it. Null for a
  /// work day. It depends only on the date and the schedule, so planning a
  /// period later continues the same sequence (#146).
  int? offDayOrdinalOf(DateTime date) {
    final day = _dateOnly(date);
    if (dayTypeOf(day) != DayType.off) return null;
    return _baseOffDaysBefore(day) + _overrideShiftBefore(day);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  Map<String, dynamic> toJson() {
    final days = overrides.keys.toList()..sort();
    return {
      'workDays': workDays,
      'offDays': offDays,
      'anchor': _iso(anchor),
      'anchorIsWork': anchorIsWork,
      if (days.isNotEmpty)
        'overrides': {
          for (final d in days)
            _iso(d): overrides[d] == DayType.work ? 'work' : 'off',
        },
    };
  }

  String encode() => jsonEncode(toJson());

  /// Reads a stored schedule; returns null for missing or invalid data. A
  /// schedule saved before the overrides existed has none; a damaged override
  /// entry is skipped.
  static WorkSchedule? tryParse(String? source) {
    if (source == null || source.isEmpty) return null;
    try {
      final json = jsonDecode(source);
      if (json is! Map) return null;
      final work = json['workDays'];
      final off = json['offDays'];
      final anchorText = json['anchor'];
      if (work is! int || off is! int || anchorText is! String) return null;
      if (work < 1 || off < 1) return null;
      final anchor = DateTime.tryParse(anchorText);
      if (anchor == null) return null;
      final overrides = <DateTime, DayType>{};
      final rawOverrides = json['overrides'];
      if (rawOverrides is Map) {
        for (final e in rawOverrides.entries) {
          final day = e.key is String ? DateTime.tryParse(e.key as String) : null;
          final type = switch (e.value) {
            'work' => DayType.work,
            'off' => DayType.off,
            _ => null,
          };
          if (day != null && type != null) overrides[day] = type;
        }
      }
      return WorkSchedule(
        workDays: work,
        offDays: off,
        anchor: anchor,
        anchorIsWork: json['anchorIsWork'] == true,
        overrides: overrides,
      );
    } on FormatException {
      return null;
    }
  }
}
