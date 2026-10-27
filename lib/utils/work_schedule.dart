import 'dart:convert';

/// Whether a day is a work day or a day off according to the work schedule.
enum DayType { work, off }

String dayTypeLabel(DayType type) =>
    type == DayType.work ? 'Рабочий день' : 'Выходной';

/// A repeating work schedule: [workDays] work days, then [offDays] days off,
/// and so on (2 / 2 is "два через два").
///
/// [anchor] is the first day of a block: of a work block if [anchorIsWork],
/// otherwise of a day-off block. The type of any date is computed from the rule,
/// nothing is stored per date (#144).
class WorkSchedule {
  final int workDays;
  final int offDays;
  final DateTime anchor;
  final bool anchorIsWork;

  WorkSchedule({
    required this.workDays,
    required this.offDays,
    required DateTime anchor,
    this.anchorIsWork = false,
  })  : assert(workDays >= 1 && offDays >= 1),
        anchor = DateTime(anchor.year, anchor.month, anchor.day);

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

  DayType dayTypeOf(DateTime date) {
    final firstBlock = anchorIsWork ? workDays : offDays;
    final firstType = anchorIsWork ? DayType.work : DayType.off;
    final secondType = anchorIsWork ? DayType.off : DayType.work;
    return _positionOf(date) < firstBlock ? firstType : secondType;
  }

  /// The number of a day off among all days off of the schedule, counted from
  /// the anchor: the first day off of the anchor's cycle is 0, the next 1, and
  /// so on (negative before the anchor). Null for a work day. It depends only
  /// on the date and the schedule, so planning a period later continues the
  /// same sequence (#146).
  int? offDayOrdinalOf(DateTime date) {
    final days = _daysFromAnchor(date);
    final position = days % cycleLength;
    final cycle = (days - position) ~/ cycleLength;
    final int indexInBlock;
    if (anchorIsWork) {
      if (position < workDays) return null;
      indexInBlock = position - workDays;
    } else {
      if (position >= offDays) return null;
      indexInBlock = position;
    }
    return cycle * offDays + indexInBlock;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  Map<String, dynamic> toJson() => {
        'workDays': workDays,
        'offDays': offDays,
        'anchor': '${anchor.year.toString().padLeft(4, '0')}-'
            '${_two(anchor.month)}-${_two(anchor.day)}',
        'anchorIsWork': anchorIsWork,
      };

  String encode() => jsonEncode(toJson());

  /// Reads a stored schedule; returns null for missing or invalid data.
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
      return WorkSchedule(
        workDays: work,
        offDays: off,
        anchor: anchor,
        anchorIsWork: json['anchorIsWork'] == true,
      );
    } on FormatException {
      return null;
    }
  }
}
