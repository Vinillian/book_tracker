import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/app_state.dart';
import '../utils/plan_date.dart';
import '../utils/plan_generator.dart';
import '../utils/work_schedule.dart';
import 'work_schedule_screen.dart';

/// What the plan screen did: days it created, or days the user chose to
/// delete (the caller deletes them with "Отменить", see `deleteNodesWithUndo`).
class PlanBatchResult {
  final List<Node> created;
  final List<Node> deleted;

  const PlanBatchResult({this.created = const [], this.deleted = const []});
}

enum _Mode { create, delete }

/// Creates day plans for a period from the work schedule and the work-day /
/// day-off templates (#145), or deletes the plans of a period (#163).
class PlanGeneratorScreen extends StatefulWidget {
  const PlanGeneratorScreen({super.key});

  @override
  State<PlanGeneratorScreen> createState() => _PlanGeneratorScreenState();
}

class _PlanGeneratorScreenState extends State<PlanGeneratorScreen> {
  static final DateFormat _full = DateFormat('dd.MM.yyyy');
  static final DateFormat _short = DateFormat('dd.MM');

  late DateTimeRange _range;
  _Mode _mode = _Mode.create;
  bool _keepWithProgress = true;

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
      helpText: 'Период',
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
    final dates = datesInRange(_range.start, _range.end);

    return Scaffold(
      appBar: AppBar(title: const Text('Планы за период')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(
                value: _Mode.create,
                icon: Icon(Icons.add),
                label: Text('Создать'),
              ),
              ButtonSegment(
                value: _Mode.delete,
                icon: Icon(Icons.delete_outline),
                label: Text('Удалить'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) =>
                setState(() => _mode = selection.first),
          ),
          const SizedBox(height: 12),
          ..._mode == _Mode.create
              ? _createBody(appState, dates)
              : _deleteBody(appState, dates),
        ],
      ),
    );
  }

  Widget _periodCard(int days) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.date_range),
        title: const Text('Период'),
        subtitle: Text(
          '${_full.format(_range.start)} - ${_full.format(_range.end)} '
          '($days дн.)',
        ),
        trailing: const Icon(Icons.edit_calendar),
        onTap: _pickRange,
      ),
    );
  }

  // ---------- Создать ----------

  List<Widget> _createBody(AppState appState, List<DateTime> dates) {
    final schedule = appState.workSchedule;
    if (schedule == null) {
      return [
        const SizedBox(height: 24),
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
      ];
    }

    final theme = Theme.of(context);
    final tooLong = dates.length > maxPlanGenerationDays;
    final preview = tooLong
        ? null
        : previewPlanGeneration(
            dates: dates,
            schedule: schedule,
            templates: appState.templates,
            hasPlan: _planDates(appState.plans).contains,
          );

    return [
      Text(schedule.summary, style: theme.textTheme.bodyMedium),
      const SizedBox(height: 8),
      _periodCard(dates.length),
      const SizedBox(height: 8),
      if (tooLong)
        Text(
          'Период слишком длинный: не больше $maxPlanGenerationDays дней.',
          style: TextStyle(color: theme.colorScheme.error),
        )
      else if (preview != null)
        ..._createPreviewLines(preview, theme),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: preview == null || preview.toCreate.isEmpty
            ? null
            : () {
                final created =
                    context.read<AppState>().generatePlans(preview);
                Navigator.pop(context, PlanBatchResult(created: created));
              },
        icon: const Icon(Icons.auto_awesome_motion),
        label: Text(
          preview == null || preview.toCreate.isEmpty
              ? 'Создавать нечего'
              : 'Создать дней: ${preview.toCreate.length}',
        ),
      ),
    ];
  }

  List<Widget> _createPreviewLines(PlanGenerationPreview preview, ThemeData theme) {
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

  // ---------- Удалить ----------

  List<Widget> _deleteBody(AppState appState, List<DateTime> dates) {
    final theme = Theme.of(context);
    final preview = previewPlanDeletion(
      dates: dates,
      plans: appState.plans,
      keepDaysWithProgress: _keepWithProgress,
    );
    final keptDates = [
      for (final plan in preview.keptWithProgress)
        if (planDateOf(plan) != null) planDateOf(plan)!,
    ];
    final count = preview.toDelete.length;

    return [
      _periodCard(dates.length),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Не удалять дни, где что-то выполнено'),
        value: _keepWithProgress,
        onChanged: (value) => setState(() => _keepWithProgress = value),
      ),
      const SizedBox(height: 4),
      Text('Будет удалено: $count', style: theme.textTheme.titleSmall),
      if (preview.deletedWithProgress > 0) ...[
        const SizedBox(height: 8),
        Text(
          'Из них дней с выполненными задачами: ${preview.deletedWithProgress}.',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ],
      if (keptDates.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          'Оставлю дни с выполненными задачами (${keptDates.length}): '
          '${_datesText(keptDates)}',
        ),
      ],
      const SizedBox(height: 8),
      const Text('Вместе с днём удаляются его заметка и записи в истории.'),
      const SizedBox(height: 16),
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: theme.colorScheme.onError,
        ),
        onPressed: count == 0 ? null : () => _confirmDelete(preview),
        icon: const Icon(Icons.delete),
        label: Text(count == 0 ? 'Удалять нечего' : 'Удалить дней: $count'),
      ),
    ];
  }

  Future<void> _confirmDelete(PlanDeletionPreview preview) async {
    final count = preview.toDelete.length;
    final withProgress = preview.deletedWithProgress;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить планы?'),
        content: Text(
          'Удалить дней: $count '
          '(${_full.format(_range.start)} - ${_full.format(_range.end)})?'
          '${withProgress > 0 ? '\nИз них с выполненными задачами: $withProgress.' : ''}'
          '\nЗаметки и записи в истории этих дней тоже удалятся. '
          'Сразу после удаления можно нажать «Отменить».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop(context, PlanBatchResult(deleted: preview.toDelete));
    }
  }
}
