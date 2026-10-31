import 'package:flutter/material.dart';
import '../../utils/work_schedule.dart';

/// The color of a day type on the calendar: work day orange, day off green.
Color dayTypeColor(DayType type) =>
    type == DayType.work ? Colors.orange : Colors.green;

/// A calendar date cell tinted by the day type from the work schedule (#171):
/// a soft disc in the color of the type behind the number. A day whose type was
/// set by hand has a thin outline in that color, today has a ring in the accent
/// color, and the selected day is filled with the accent color. Dates of the
/// neighbouring months are dimmed. Meant for `CalendarBuilders.prioritizedBuilder`;
/// the plan ring and the done dot are drawn over it by the calendar.
class ScheduleDayCell extends StatelessWidget {
  final int dayNumber;
  final DayType type;
  final bool overridden;
  final bool selected;
  final bool today;
  final bool outside;

  const ScheduleDayCell({
    super.key,
    required this.dayNumber,
    required this.type,
    this.overridden = false,
    this.selected = false,
    this.today = false,
    this.outside = false,
  });

  /// The soft fill behind the number of a day of [type].
  static Color fillOf(DayType type, {bool dim = false}) =>
      dayTypeColor(type).withValues(alpha: dim ? 0.08 : 0.22);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = dayTypeColor(type);

    final Color fill = selected ? scheme.primary : fillOf(type, dim: outside);
    final Color textColor = selected
        ? scheme.onPrimary
        : outside
            ? scheme.onSurface.withValues(alpha: 0.4)
            : scheme.onSurface;
    final Border? border = selected
        ? null
        : today
            ? Border.all(color: scheme.primary, width: 2)
            : overridden
                ? Border.all(color: color, width: 1.5)
                : null;

    return Container(
      margin: const EdgeInsets.all(6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: border,
      ),
      child: Text(
        '$dayNumber',
        style: TextStyle(
          color: textColor,
          fontWeight: today || selected ? FontWeight.bold : null,
        ),
      ),
    );
  }
}

/// The key to the colors of [ScheduleDayCell]: work day, day off, set by hand.
class ScheduleLegend extends StatelessWidget {
  const ScheduleLegend({super.key});

  Widget _swatch(Color fill, {Color? outline}) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: outline == null ? null : Border.all(color: outline, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    Widget entry(Widget swatch, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [swatch, const SizedBox(width: 4), Text(label, style: style)],
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 4,
      children: [
        entry(_swatch(ScheduleDayCell.fillOf(DayType.work)), 'Рабочий день'),
        entry(_swatch(ScheduleDayCell.fillOf(DayType.off)), 'Выходной'),
        entry(
          _swatch(Colors.transparent, outline: Colors.grey),
          'Изменён вручную',
        ),
      ],
    );
  }
}
