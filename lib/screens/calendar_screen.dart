import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/history_entry.dart';
import '../models/node.dart';
import '../providers/app_state.dart';
import '../utils/day_part.dart';
import '../utils/delete_with_undo.dart';
import '../utils/format_minutes.dart';
import '../utils/plan_date.dart';
import '../utils/tracking_id.dart';
import 'components/day_type_chip.dart';
import 'components/schedule_day_cell.dart';
import '../services/history_service.dart';
import 'book_screen.dart';
import 'plan_generator_screen.dart';
import 'components/app_drawer_menu.dart';
import 'components/app_menu_button.dart';
import 'components/quick_add_bar.dart';
import 'components/standard_task_quick_picker.dart';
import 'template_manager_screen.dart';

enum _NewDayChoice { empty, template }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const Object _planMarker = Object();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.twoWeeks;

  Map<DateTime, List<HistoryEntry>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<HistoryEntry> _getEventsForDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return _events[normalized] ?? [];
  }

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  Set<DateTime> _planDays(List<Node> plans) {
    final days = <DateTime>{};
    for (final plan in plans) {
      final date = planDateOf(plan);
      if (date != null) days.add(_dayKey(date));
    }
    return days;
  }

  Widget _markerDot({required bool filled}) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled ? Colors.blue : null,
      border: Border.all(color: Colors.blue, width: 1.5),
    ),
  );

  Widget _legend(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _markerDot(filled: false),
        const SizedBox(width: 4),
        Text('План', style: style),
        const SizedBox(width: 12),
        _markerDot(filled: true),
        const SizedBox(width: 4),
        Text('Выполнено', style: style),
      ],
    );
  }

  Node? _existingPlanForDay(DateTime day) =>
      context.read<AppState>().planForDate(day);

  Future<void> _openDay(DateTime day) async {
    final existing = _existingPlanForDay(day);
    if (existing != null) {
      await _showDay(existing);
      return;
    }

    final choice = await _askHowToCreate(day);
    if (choice == null || !mounted) return;

    final appState = context.read<AppState>();
    Node? created;

    if (choice == _NewDayChoice.empty) {
      created = appState.addEmptyDay(day);
    } else {
      final template = await Navigator.push<Node>(
        context,
        MaterialPageRoute(
          builder: (_) => const TemplateManagerScreen(
            selectionMode: true,
            filterCategory: 'planner',
          ),
        ),
      );

      if (template == null || !mounted) return;
      created = appState.addDayFromTemplate(template, day);
    }

    if (!mounted) return;
    await _showDay(created);
  }

  Future<_NewDayChoice?> _askHowToCreate(DateTime day) {
    final dateStr = DateFormat('dd.MM.yyyy').format(day);

    return showModalBottomSheet<_NewDayChoice>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Плана на $dateStr нет',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Пустой день'),
              onTap: () => Navigator.pop(ctx, _NewDayChoice.empty),
            ),
            ListTile(
              leading: const Icon(Icons.copy_all),
              title: const Text('Из шаблона'),
              onTap: () => Navigator.pop(ctx, _NewDayChoice.template),
            ),
          ],
        ),
      ),
    );
  }

  void _createEmptyPlan(DateTime day) {
    context.read<AppState>().addEmptyDay(day);
  }

  void _addTaskToPlan(Node plan, Node task) {
    final appState = context.read<AppState>();
    plan.children.add(task);
    appState.updateNode(appState.getKeyForNode(plan), plan);
  }

  Future<void> _openStandardTaskPicker(Node plan, [int? startMinutes]) {
    final appState = context.read<AppState>();

    return showStandardTaskQuickPicker(
      context,
      startMinutes: startMinutes,
      onPick: (task, selectedStartMinutes) {
        final node = task.toNode();
        node.startMinutes = selectedStartMinutes;
        node.trackingId = resolveTrackingId(
          task.name,
          tracked: appState.trackedActivities,
          roots: [...appState.books, ...appState.plans, ...appState.templates],
          fallback: task.trackingId,
        );
        _addTaskToPlan(plan, node);
      },
    );
  }

  Future<void> _openPlanBatch() async {
    final result = await Navigator.push<PlanBatchResult>(
      context,
      MaterialPageRoute(builder: (_) => const PlanGeneratorScreen()),
    );

    if (result == null || !mounted) return;

    if (result.deleted.isNotEmpty) {
      deleteNodesWithUndo(
        context,
        result.deleted,
        message: 'Удалено дней: ${result.deleted.length}',
      );
      return;
    }

    if (result.created.isEmpty) return;

    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Создано дней: ${result.created.length}'),
        duration: const Duration(seconds: 8),
        persist: false,
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () => appState.removeGeneratedDays(result.created),
        ),
      ),
    );
  }

  Future<void> _showDay(Node plan) async {
    final appState = context.read<AppState>();
    final key = appState.getKeyForNode(plan);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookScreen(
          node: plan,
          onNodeUpdated: () => appState.updateNode(key, plan),
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final planDays = _planDays(appState.plans);
    final schedule = appState.workSchedule;
    final today = DateTime.now();

    final selectedPlan = _selectedDay == null
        ? null
        : appState.planForDate(_selectedDay!);

    _events = HistoryService.getAllEntriesGroupedByDate();

    List<Object> markersForDay(DateTime day) => [
      ..._getEventsForDay(day),
      if (planDays.contains(_dayKey(day))) _planMarker,
    ];

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Календарь прогресса'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_motion),
            tooltip: 'Планы за период: создать или удалить',
            onPressed: _openPlanBatch,
          ),
          const AppMenuButton(),
        ],
      ),
      endDrawer: const AppDrawerMenu(),
      body: Column(
        children: [
          // Календарь с переключением между двумя неделями и месяцем.
          TableCalendar<Object>(
            locale: 'ru_RU',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableCalendarFormats: const {
              CalendarFormat.twoWeeks: '2 недели',
              CalendarFormat.month: 'Месяц',
            },
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: markersForDay,
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: true,
              formatButtonShowsNext: false,
              formatButtonDecoration: BoxDecoration(
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              formatButtonTextStyle: const TextStyle(fontSize: 12),
              titleTextFormatter: (date, locale) =>
                  DateFormat.yMMMM('ru_RU').format(date),
              headerPadding: const EdgeInsets.symmetric(vertical: 2),
              leftChevronMargin: const EdgeInsets.only(left: 4),
              rightChevronMargin: const EdgeInsets.only(right: 4),
              leftChevronPadding: const EdgeInsets.all(4),
              rightChevronPadding: const EdgeInsets.all(4),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontSize: 11),
              weekendStyle: TextStyle(fontSize: 11),
            ),
            calendarStyle: const CalendarStyle(
              cellMargin: EdgeInsets.all(2),
              cellPadding: EdgeInsets.zero,
              outsideDaysVisible: false,
              markersMaxCount: 2,
              markerSize: 6,
              markersAlignment: Alignment.bottomCenter,
              markersOffset: PositionedOffset(bottom: 2),
            ),
            rowHeight: 38,
            calendarBuilders: CalendarBuilders<Object>(
              prioritizedBuilder: schedule == null
                  ? null
                  : (context, day, focusedDay) => ScheduleDayCell(
                      dayNumber: day.day,
                      type: schedule.dayTypeOf(day),
                      overridden: schedule.isOverridden(day),
                      selected: isSameDay(_selectedDay, day),
                      today: isSameDay(today, day),
                      outside: day.month != focusedDay.month,
                    ),
              markerBuilder: (context, day, events) {
                final hasPlan = events.contains(_planMarker);
                final hasHistory = events.any((e) => e is HistoryEntry);

                return Positioned(
                  bottom: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasPlan) _markerDot(filled: false),
                      if (hasPlan && hasHistory) const SizedBox(width: 3),
                      if (hasHistory) _markerDot(filled: true),
                    ],
                  ),
                );
              },
            ),
          ),

          // Легенда календаря и графика.
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _legend(context),
          ),
          if (schedule != null)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: ScheduleLegend(),
            ),

          // Фиксированная информация о выбранном дне.
          if (_selectedDay != null)
            _buildSelectedDayHeader(appState, selectedPlan, scheme),

          // Прокручивается только содержимое выбранного дня.
          Expanded(
            child: _selectedDay == null
                ? const SizedBox.shrink()
                : _buildDayTasks(appState),
          ),

          if (selectedPlan != null)
            QuickAddBar(
              onAdd: (name, startMinutes) {
                _addTaskToPlan(
                  selectedPlan,
                  Node.leaf(name)..startMinutes = startMinutes,
                );
              },
              onOpenPicker: (startMinutes) =>
                  _openStandardTaskPicker(selectedPlan, startMinutes),
            ),
        ],
      ),
    );
  }

  /// Закреплённая панель выбранной даты, типа дня и общего прогресса.
  Widget _buildSelectedDayHeader(
    AppState appState,
    Node? plan,
    ColorScheme scheme,
  ) {
    final day = _selectedDay!;
    final theme = Theme.of(context);

    final total = plan?.totalLeaves ?? 0;
    final done = plan?.completedLeaves ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('dd.MM.yyyy').format(day),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              DayTypeChip(date: day),
              const Spacer(),
              if (plan == null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'Нет плана',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _openDay(day),
                child: Text(plan == null ? 'Создать план' : 'Открыть день'),
              ),
            ],
          ),
          if (plan != null && total > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Выполнено $done из $total',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  '${(done / total * 100).round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: done / total, minHeight: 4),
            ),
          ],
        ],
      ),
    );
  }

  /// Прокручиваемый список задач выбранного дня.
  Widget _buildDayTasks(AppState appState) {
    final day = _selectedDay!;
    final theme = Theme.of(context);
    final plan = appState.planForDate(day);

    if (plan == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: [
          const Text('Плана на этот день пока нет.'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _createEmptyPlan(day),
            icon: const Icon(Icons.add),
            label: const Text('Создать пустой план'),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: _planSummary(plan, theme),
    );
  }

  List<Widget> _planSummary(Node plan, ThemeData theme) {
    final timed = sortedByStartTime([
      for (final c in plan.children)
        if (c.startMinutes != null) c,
    ]);

    final untimed = [
      for (final c in plan.children)
        if (c.startMinutes == null) c,
    ];

    return [
      if (plan.children.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text('В плане пока нет задач'),
        ),
      for (final task in [...timed, ...untimed])
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: _taskLeading(task),
          title: Text.rich(
            TextSpan(
              children: [
                if (task.startMinutes != null)
                  TextSpan(
                    text: '${formatMinutes(task.startMinutes!)}  ',
                    style: const TextStyle(color: Colors.grey),
                  ),
                TextSpan(
                  text: task.name.isEmpty ? '[Без названия]' : task.name,
                ),
              ],
            ),
          ),
          trailing: _taskTrailing(task),
        ),
    ];
  }

  Widget? _taskLeading(Node task) {
    final hasChildren = task.children.isNotEmpty;
    final isSingle = task.stepType == 'single';

    final isFolder =
        task.stepType == 'folder' || (hasChildren && !task.hasOwnProgress);

    if (isSingle && (!hasChildren || task.hasOwnProgress)) {
      return Icon(
        task.completed ? Icons.check_circle : Icons.radio_button_unchecked,
        color: task.completed ? Colors.green : Colors.grey,
      );
    }

    if (isFolder) {
      return Icon(task.isExpanded ? Icons.folder_open : Icons.folder);
    }

    return const Icon(Icons.list, color: Colors.blue);
  }

  Widget? _taskTrailing(Node task) {
    final total = task.totalLeaves;
    Widget? progress;

    if (total > 0 && (task.children.isNotEmpty || task.stepType != 'single')) {
      progress = Text('${task.completedLeaves}/$total');
    }

    final hasTime = (task.targetMinutes ?? 0) > 0 || task.loggedMinutes > 0;

    if (!hasTime) return progress;

    final time = Text(
      durationProgressLabel(task.loggedMinutes, task.targetMinutes),
      style: TextStyle(
        fontSize: 11,
        color: task.timeGoalReached ? Colors.green : Colors.grey,
      ),
    );

    if (progress == null) return time;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [progress, const SizedBox(width: 6), time],
    );
  }

}
