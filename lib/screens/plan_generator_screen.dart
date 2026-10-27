import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/app_state.dart';
import '../utils/plan_date.dart';
import '../utils/plan_generator.dart';
import '../utils/work_schedule.dart';
import 'work_schedule_screen.dart';

/// Creates day plans for a period from the work schedule and the work-day /
/// day-off templates (#145). Pops with the list of created days.
class PlanGeneratorScreen extends StatefulWidget {
  const PlanGeneratorScreen({super.key});

  @override
  State<PlanGeneratorScreen> createState() => _PlanGeneratorScreenState();
}

class _PlanGeneratorScreenState extends State<PlanGeneratorScreen> {
  static final DateFormat _full = DateFormat('dd.MM.yyyy');
  static final DateFormat _short = DateFormat('dd.MM');

  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _range = DateTimeRange(
      start: today,
      end: DateTime(today.year, today.month, today.day + 13),
    );
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      initialDateRange: _range,
      helpText: 'Период для планов',
    );
    if (picked != null) setState(() => _range = picked);
  }

  String _datesText(List<DateTime> days) {
    const shown = 8;
    final head = days.take(shown).map(_short.format).join(', ');
    return days.length > shown ? '$head и ещё ${days.length - shown}' : head;
  }

  Set<DateTime> _planDates(List<Node> plans) {
    final dates = <DateTime>{};
    for (final plan in plans) {
      final date = planDateOf(plan);
      if (date != null) dates.add(date);
    }
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final schedule = appState.workSchedule;

    return Scaffold(
      appBar: AppBar(title: const Text('Сгенерировать планы')),
      body: schedule == null ? _noSchedule() : _content(appState, schedule),
    );
  }

  Widget _noSchedule() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'График работы не задан: без него неизвестно, какой день рабочий, '
            'а какой выходной.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorkScheduleScreen()),
            ),
            child: const Text('Настроить график'),
          ),
        ],
      ),
    );
  }

  Widget _content(AppState appState, WorkSchedule schedule) {
    final dates = datesInRange(_range.start, _range.end);
    final tooLong = dates.length > maxPlanGenerationDays;
    final planDates = _planDates(appState.plans);
    final preview = tooLong
        ? null
        : previewPlanGeneration(
            dates: dates,
            schedule: schedule,
            templates: appState.templates,
            hasPlan: planDates.contains,
          );
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(schedule.summary, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('Период'),
            subtitle: Text(
              '${_full.format(_range.start)} - ${_full.format(_range.end)} '
              '(${dates.length} дн.)',
            ),
            trailing: const Icon(Icons.edit_calendar),
            onTap: _pickRange,
          ),
        ),
        const SizedBox(height: 8),
        if (tooLong)
          Text(
            'Период слишком длинный: не больше $maxPlanGenerationDays дней.',
            style: TextStyle(color: theme.colorScheme.error),
          )
        else if (preview != null) ..._previewLines(preview, theme),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: preview == null || preview.toCreate.isEmpty
              ? null
              : () {
                  final created = context.read<AppState>().generatePlans(preview);
                  Navigator.pop(context, created);
                },
          icon: const Icon(Icons.auto_awesome_motion),
          label: Text(
            preview == null || preview.toCreate.isEmpty
                ? 'Создавать нечего'
                : 'Создать дней: ${preview.toCreate.length}',
          ),
        ),
      ],
    );
  }

  List<Widget> _previewLines(PlanGenerationPreview preview, ThemeData theme) {
    return [
      Text(
        'Будет создано: ${preview.toCreate.length} '
        '(рабочих: ${preview.workCount}, выходных: ${preview.offCount})',
        style: theme.textTheme.titleSmall,
      ),
      if (preview.existing.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          'Уже есть план, не трогаю (${preview.existing.length}): '
          '${_datesText(preview.existing)}',
        ),
      ],
      if (preview.withoutTemplate.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          'Нет шаблона для ${_missingTypesText(preview.missingTemplates)} '
          '- эти дни пропущены (${preview.withoutTemplate.length}): '
          '${_datesText(preview.withoutTemplate)}. Создайте шаблон на экране '
          '«Шаблоны» и задайте ему тип «Рабочий день» или «Выходной».',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ],
    ];
  }

  String _missingTypesText(Set<DayType> types) {
    final names = [
      if (types.contains(DayType.work)) 'рабочих дней',
      if (types.contains(DayType.off)) 'выходных',
    ];
    return names.join(' и ');
  }
}
