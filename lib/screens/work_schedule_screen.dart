import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../utils/work_schedule.dart';

/// Edits the work schedule (#144): N work days, M days off, an anchor day and
/// its type, with a preview of the next days.
class WorkScheduleScreen extends StatefulWidget {
  const WorkScheduleScreen({super.key});

  @override
  State<WorkScheduleScreen> createState() => _WorkScheduleScreenState();
}

class _WorkScheduleScreenState extends State<WorkScheduleScreen> {
  late bool _enabled;
  late int _workDays;
  late int _offDays;
  late DateTime _anchor;
  late bool _anchorIsWork;
  late Map<DateTime, DayType> _overrides;

  @override
  void initState() {
    super.initState();
    final current = context.read<AppState>().workSchedule;
    _enabled = current != null;
    _workDays = current?.workDays ?? 2;
    _offDays = current?.offDays ?? 2;
    final now = DateTime.now();
    _anchor = current?.anchor ?? DateTime(now.year, now.month, now.day);
    _anchorIsWork = current?.anchorIsWork ?? false;
    _overrides = {...?current?.overrides};
  }

  WorkSchedule get _schedule => WorkSchedule(
        workDays: _workDays,
        offDays: _offDays,
        anchor: _anchor,
        anchorIsWork: _anchorIsWork,
        overrides: _overrides,
      );

  Future<void> _pickAnchor() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Первый день блока',
    );
    if (picked == null || !mounted) return;
    setState(() => _anchor = DateTime(picked.year, picked.month, picked.day));
  }

  void _save() {
    context.read<AppState>().setWorkSchedule(_enabled ? _schedule : null);
    Navigator.pop(context);
  }

  Widget _counter(String label, int value, void Function(int) onChanged) {
    return ListTile(
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
          ),
          Text('$value', style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: value < 14 ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    final schedule = _schedule;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final fmt = DateFormat('dd.MM');
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < 14; i++)
          Builder(builder: (context) {
            final day = start.add(Duration(days: i));
            final isWork = schedule.dayTypeOf(day) == DayType.work;
            final color = isWork ? Colors.orange : Colors.green;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                border: Border.all(color: color),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${fmt.format(day)} ${isWork ? 'раб.' : 'вых.'}',
                style: const TextStyle(fontSize: 12),
              ),
            );
          }),
      ],
    );
  }

  /// Days whose type was set by hand (a holiday, a swapped shift): they can be
  /// brought back to the rule here. Applied with "Сохранить" like the rest.
  List<Widget> _overridesSection() {
    if (_overrides.isEmpty) return const [];
    final schedule = _schedule;
    final days = _overrides.keys.toList()..sort();
    final fmt = DateFormat('dd.MM.yyyy');
    return [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Text(
          'Изменено вручную',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      for (final day in days)
        ListTile(
          dense: true,
          title: Text('${fmt.format(day)}: ${dayTypeLabel(_overrides[day]!)}'),
          subtitle: Text('По графику: ${dayTypeLabel(schedule.baseDayTypeOf(day))}'),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Вернуть по графику',
            onPressed: () =>
                setState(() => _overrides = {..._overrides}..remove(day)),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => setState(() => _overrides = {}),
          child: const Text('Вернуть все по графику'),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('График работы')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Использовать график'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          if (_enabled) ...[
            _counter('Рабочих дней подряд', _workDays,
                (v) => setState(() => _workDays = v)),
            _counter('Выходных дней подряд', _offDays,
                (v) => setState(() => _offDays = v)),
            ListTile(
              title: const Text('Первый день блока'),
              subtitle: Text(DateFormat('dd.MM.yyyy').format(_anchor)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickAnchor,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Выходной')),
                    ButtonSegment(value: true, label: Text('Рабочий')),
                  ],
                  selected: {_anchorIsWork},
                  onSelectionChanged: (s) =>
                      setState(() => _anchorIsWork = s.first),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'С этого дня начинается блок выбранного типа, дальше график повторяется.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Ближайшие 14 дней',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _preview(),
            ),
            ..._overridesSection(),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _save,
              child: const Text('Сохранить'),
            ),
          ),
        ],
      ),
    );
  }
}
