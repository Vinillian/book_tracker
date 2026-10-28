import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../utils/work_schedule.dart';

enum _DayTypeAction { makeWork, makeOff, reset }

/// "Рабочий день" / "Выходной" for [date] from the work schedule; a tap opens
/// a menu to set the type by hand (a holiday, a swapped shift) or to bring the
/// schedule's rule back (#144). Nothing is shown while no schedule is set.
class DayTypeChip extends StatelessWidget {
  final DateTime date;

  const DayTypeChip({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final type = appState.dayTypeOf(date);
    if (type == null) return const SizedBox.shrink();
    final overridden = appState.isDayTypeOverridden(date);
    final isWork = type == DayType.work;
    final color = isWork ? Colors.orange : Colors.green;

    return PopupMenuButton<_DayTypeAction>(
      tooltip: 'Изменить тип дня',
      onSelected: (action) {
        final state = context.read<AppState>();
        switch (action) {
          case _DayTypeAction.makeWork:
            state.setDayTypeOverride(date, DayType.work);
          case _DayTypeAction.makeOff:
            state.setDayTypeOverride(date, DayType.off);
          case _DayTypeAction.reset:
            state.setDayTypeOverride(date, null);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: isWork ? _DayTypeAction.makeOff : _DayTypeAction.makeWork,
          child: Text(isWork ? 'Сделать выходным' : 'Сделать рабочим'),
        ),
        if (overridden)
          const PopupMenuItem(
            value: _DayTypeAction.reset,
            child: Text('Вернуть по графику'),
          ),
      ],
      child: Chip(
        avatar: Icon(
          isWork ? Icons.work_outline : Icons.weekend_outlined,
          size: 18,
          color: color,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              overridden
                  ? '${dayTypeLabel(type)} (вручную)'
                  : dayTypeLabel(type),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
        backgroundColor: color.withValues(alpha: 0.15),
        side: BorderSide(color: color),
      ),
    );
  }
}
