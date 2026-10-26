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

  /// Position of [date] inside the cycle, 0 = the anchor day. Calendar days are
  /// counted in UTC so daylight saving time cannot shift the result.
  int _positionOf(DateTime date) {
    final days = DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(anchor.year, anchor.month, anchor.day))
        .inDays;
    return days % cycleLength; // Dart's % is never negative here
  }

  DayType dayTypeOf(DateTime date) {
    final firstBlock = anchorIsWork ? workDays : offDays;
    final firstType = anchorIsWork ? DayType.work : DayType.off;
    final secondType = anchorIsWork ? DayType.off : DayType.work;
    return _positionOf(date) < firstBlock ? firstType : secondType;
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
