import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../utils/work_schedule.dart';

enum _DayTypeAction { makeWork, makeOff, reset }

/// Компактная кнопка типа дня с меню ручного изменения.
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
    final label = isWork ? 'Рабочий' : 'Выходной';

    return PopupMenuButton<_DayTypeAction>(
      tooltip: 'Изменить тип дня',
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(8),
              color: color.withValues(alpha: 0.08),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isWork ? Icons.weekend_outlined : Icons.work_outline,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(isWork ? 'Сделать выходным' : 'Сделать рабочим'),
              ],
            ),
          ),
        ),
        if (overridden)
          PopupMenuItem(
            value: _DayTypeAction.reset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restart_alt, size: 18),
                  SizedBox(width: 8),
                  Text('Вернуть по графику'),
                ],
              ),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isWork ? Icons.work_outline : Icons.weekend_outlined,
              size: 17,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (overridden) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: 'Изменено вручную',
                child: Icon(Icons.edit, size: 13, color: color),
              ),
            ],
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}
