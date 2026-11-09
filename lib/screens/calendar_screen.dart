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
  // Marker object meaning "a plan exists on this day" (history entries are
  // HistoryEntry instances), so the two kinds can be drawn differently.
  static const Object _planMarker = Object();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
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
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _markerDot(filled: false),
        const SizedBox(width: 4),
        Text('План', style: style),
        const SizedBox(width: 16),
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

  /// Creates an empty plan without leaving the calendar. The quick-add bar
  /// appears automatically after AppState notifies its listeners.
  void _createEmptyPlan(DateTime day) {
    context.read<AppState>().addEmptyDay(day);
  }

  /// Adds a task directly to the selected day's existing plan.
  void _addTaskToPlan(Node plan, Node task) {
    final appState = context.read<AppState>();
    plan.children.add(task);
    appState.updateNode(appState.getKeyForNode(plan), plan);
  }

  /// Reuses the same standard-task picker and tracking-ID resolution as
  /// BookScreen, so calendar-created tasks join existing tracking lines.
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

  /// Opens the screen that creates or deletes plans for a period; offers to
  /// undo the whole batch afterwards (#145, #163).
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

    // Re-read History on every build: it changes elsewhere (deleting a plan,
    // ticking tasks), and AppState notifications rebuild this screen.
    _events = HistoryService.getAllEntriesGroupedByDate();
    List<Object> markersForDay(DateTime day) => [
      ..._getEventsForDay(day),
      if (planDays.contains(_dayKey(day))) _planMarker,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Календарь прогресса'),
        ),
        // With explicit actions Flutter does not add the end-drawer button.
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
          TableCalendar<Object>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            // A tap only selects the day and shows its summary below; the day
            // itself opens with the button in the summary.
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: markersForDay,
            calendarBuilders: CalendarBuilders<Object>(
              // With a work schedule every date is tinted by its day type
              // (#171); the markers below are still drawn over the cell.
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
                  bottom: 4,
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
          _legend(context),
          if (schedule != null) ...[
            const SizedBox(height: 4),
            const ScheduleLegend(),
          ],
          const SizedBox(height: 8),
          Expanded(child: _buildDaySummary(appState)),
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

  /// A short summary of the selected day under the calendar (#145): its type,
  /// the plan's tasks with their progress, and what History recorded.
  Widget _buildDaySummary(AppState appState) {
    final day = _selectedDay;
    if (day == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final plan = appState.planForDate(day);
    final events = _getEventsForDay(day);

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd.MM.yyyy').format(day),
                      style: theme.textTheme.titleMedium,
                    ),
                    DayTypeChip(date: day),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () => _openDay(day),
                child: Text(plan == null ? 'Создать план…' : 'Открыть день'),
              ),
            ],
          ),
        ),
        if (plan == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Плана на этот день нет'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _createEmptyPlan(day),
                  icon: const Icon(Icons.add),
                  label: const Text('Создать пустой план для добавления задач'),
                ),
              ],
            ),
          )
        else
          ..._planSummary(plan, theme),
        if (events.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Выполнено', style: theme.textTheme.titleSmall),
          ),
          ..._historyCards(events),
        ],
      ],
    );
  }

  List<Widget> _planSummary(Node plan, ThemeData theme) {
    final total = plan.totalLeaves;
    final done = plan.completedLeaves;

    final timed = sortedByStartTime([
      for (final c in plan.children)
        if (c.startMinutes != null) c,
    ]);

    final untimed = [
      for (final c in plan.children)
        if (c.startMinutes == null) c,
    ];

    return [
      if (total > 0)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Выполнено $done из $total'),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: done / total),
            ],
          ),
        ),
      if (plan.children.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text('В плане пока нет задач'),
        ),
      for (final task in [...timed, ...untimed])
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
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

    // Числовой прогресс показываем только для составных задач.
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

  List<Widget> _historyCards(List<HistoryEntry> events) {
    return [
      for (final entry in events)
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: entry.stepType == 'single'
                ? Icon(
                    entry.completed == true
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: entry.completed == true ? Colors.green : Colors.grey,
                  )
                : entry.stepType == 'duration'
                ? const Icon(Icons.timer, color: Colors.blue)
                : const Icon(Icons.list, color: Colors.blue),
            title: Text(entry.nodeName),
            subtitle: entry.stepType == 'single'
                ? Text(entry.completed == true ? 'Выполнено' : 'Не выполнено')
                : null,
            trailing: entry.stepType == 'stepByStep'
                ? Text('Шагов: ${entry.completedSteps}')
                : entry.stepType == 'duration'
                ? Text(formatDuration(entry.minutes ?? 0))
                : null,
          ),
        ),
    ];
  }
}
