import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/history_entry.dart';
import '../models/node.dart';
import '../models/tracked_activity.dart';
import '../providers/app_state.dart';
import '../services/history_service.dart';
import '../utils/format_minutes.dart';

class ViewItemScreen extends StatefulWidget {
  final String bookId;
  final Node node;
  final VoidCallback onNodeUpdated;
  final DateTime? targetDate;

  const ViewItemScreen({
    super.key,
    required this.bookId,
    required this.node,
    required this.onNodeUpdated,
    this.targetDate,
  });

  @override
  State<ViewItemScreen> createState() => _ViewItemScreenState();
}

class _ViewItemScreenState extends State<ViewItemScreen> {
  late Node _node;
  late int _tempSteps;

  @override
  void initState() {
    super.initState();
    _node = widget.node;
    _tempSteps = _node.completedSteps;
  }

  /// Возвращает дату/время для записи в историю: если план на сегодня —
  /// текущий момент как есть (сохраняет реальное время суток, а не
  /// полночь). Если план на другой день — дата самого плана, но с
  /// текущим временем суток, чтобы отметка попадала на правильный
  /// календарный день (важно для heatmap/статистики), а не на "сегодня".
  DateTime _resolveEventDate() {
    final now = DateTime.now();
    final target = widget.targetDate;
    if (target == null) return now;
    final isToday = target.year == now.year &&
        target.month == now.month &&
        target.day == now.day;
    if (isToday) return now;
    return DateTime(
      target.year,
      target.month,
      target.day,
      now.hour,
      now.minute,
      now.second,
    );
  }

  void _onToggle(bool? value) {
    final newValue = value ?? false;
    setState(() {
      _node.completed = newValue;
    });
    if (!_node.excludeFromHistory) {
      HistoryService.recordUniqueToggle(
        bookId: widget.bookId,
        node: _node,
        newValue: newValue,
        targetDate: _resolveEventDate(),
      );
    }
    widget.onNodeUpdated();
  }

  /// Logs [minutes] on this duration task: adds them to the task and, unless
  /// the task is excluded from History, records one History entry (#112).
  Future<void> _addMinutes(int minutes) async {
    if (minutes <= 0 || !_node.hasOwnProgress) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Добавить ${formatDuration(minutes)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Продолжить после последней сессии'),
              onTap: () => Navigator.pop(ctx, 'continue'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Выбрать время начала'),
              onTap: () => Navigator.pop(ctx, 'choose'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    final selectedDay = widget.targetDate ?? DateTime.now();
    DateTime start;
    if (choice == 'continue') {
      start = HistoryService.suggestDurationStart(
        nodeId: _node.id,
        day: selectedDay,
        plannedStartMinutes: _node.startMinutes,
      );
    } else {
      final initial = _resolveEventDate();
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: DateUtils.dateOnly(initial),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (pickedDate == null || !mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
      if (pickedTime == null || !mounted) return;
      start = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    }

    final end = start.add(Duration(minutes: minutes));
    setState(() => _node.loggedMinutes += minutes);
    if (!_node.excludeFromHistory) {
      HistoryService.recordDurationLog(
        bookId: widget.bookId,
        node: _node,
        minutes: minutes,
        targetDate: end,
        startedAt: start,
        endedAt: end,
      );
    }
    widget.onNodeUpdated();
  }

  /// Removes one log: its History entry goes and its minutes leave the task.
  void _removeLog(HistoryEntry entry) {
    if (!HistoryService.deleteEntryById(entry.id)) return;
    setState(() {
      _node.loggedMinutes =
          math.max(0, _node.loggedMinutes - (entry.minutes ?? 0));
    });
    widget.onNodeUpdated();
  }

  Future<void> _editLog(HistoryEntry entry) async {
    var end = entry.endedAt ?? entry.date;
    var start = entry.startedAt ??
        end.subtract(Duration(minutes: entry.minutes ?? 0));
    String? validationError;

    final interval = await showDialog<({DateTime start, DateTime end})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickDate({required bool isStart}) async {
            final current = isStart ? start : end;
            final picked = await showDatePicker(
              context: dialogContext,
              initialDate: DateUtils.dateOnly(current),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (picked == null) return;
            setDialogState(() {
              final updated = DateTime(
                picked.year,
                picked.month,
                picked.day,
                current.hour,
                current.minute,
              );
              if (isStart) {
                start = updated;
              } else {
                end = updated;
              }
              validationError = null;
            });
          }

          Future<void> pickTime({required bool isStart}) async {
            final current = isStart ? start : end;
            final picked = await showTimePicker(
              context: dialogContext,
              initialTime: TimeOfDay.fromDateTime(current),
              builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(
                  alwaysUse24HourFormat: true,
                ),
                child: child!,
              ),
            );
            if (picked == null) return;
            setDialogState(() {
              final updated = DateTime(
                current.year,
                current.month,
                current.day,
                picked.hour,
                picked.minute,
              );
              if (isStart) {
                start = updated;
              } else {
                end = updated;
              }
              validationError = null;
            });
          }

          Widget intervalControls({
            required String label,
            required DateTime value,
            required bool isStart,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => pickDate(isStart: isStart),
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(DateFormat('dd.MM.yyyy').format(value)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => pickTime(isStart: isStart),
                        icon: const Icon(Icons.access_time, size: 18),
                        label: Text(DateFormat('HH:mm').format(value)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          final minutes = end.difference(start).inMinutes;
          return AlertDialog(
            title: const Text('Изменить интервал сессии'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                intervalControls(
                  label: 'Начало',
                  value: start,
                  isStart: true,
                ),
                const SizedBox(height: 16),
                intervalControls(
                  label: 'Окончание',
                  value: end,
                  isStart: false,
                ),
                const SizedBox(height: 12),
                Text('Длительность: ${formatDuration(minutes)}'),
                if (validationError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    validationError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () {
                  if (minutes < 1 || minutes > 1440) {
                    setDialogState(() {
                      validationError =
                          'Интервал должен быть от 1 минуты до 24 часов.';
                    });
                    return;
                  }
                  Navigator.pop(dialogContext, (start: start, end: end));
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );

    if (interval == null || !mounted) return;
    final minutes = interval.end.difference(interval.start).inMinutes;
    final oldMinutes = entry.minutes ?? 0;
    if (!HistoryService.updateDurationLog(
      id: entry.id,
      minutes: minutes,
      startedAt: interval.start,
      endedAt: interval.end,
    )) {
      return;
    }
    setState(() {
      _node.loggedMinutes =
          math.max(0, _node.loggedMinutes - oldMinutes + minutes);
    });
    widget.onNodeUpdated();
  }

  Future<void> _addCustomMinutes() async {
    // Not disposed on purpose: the dialog is still animating out when the
    // future completes, and disposing then would throw.
    final controller = TextEditingController();
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сколько минут добавить?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: 'От 1 до 1440'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, (v != null && v >= 1 && v <= 1440) ? v : null);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    if (minutes != null && mounted) await _addMinutes(minutes);
  }

  void _onSliderChanged(double value) {
    setState(() {
      _tempSteps = value.round();
    });
  }

  void _onSliderChangeEnd(double value) {
    final newSteps = value.round();
    final oldSteps = _node.completedSteps;
    if (newSteps != oldSteps) {
      setState(() {
        _node.completedSteps = newSteps;
        _tempSteps = newSteps;
      });
      if (!_node.excludeFromHistory) {
        HistoryService.recordUniqueProgress(
          bookId: widget.bookId,
          node: _node,
          newSteps: newSteps,
          previousSteps: oldSteps,
          targetDate: _resolveEventDate(),
        );
      }
      widget.onNodeUpdated();
    }
  }

  /// The task's logged times (History entries), newest first, each removable.
  List<Widget> _buildLogList() {
    final logs = HistoryService.getDurationEntriesForNode(_node.id);
    if (logs.isEmpty) return const [];
    return [
      const SizedBox(height: 16),
      Text(
        'Сессии (${logs.length}):',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      for (final e in logs.take(20))
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.timer, size: 20),
          title: Text(formatDuration(e.minutes ?? 0)),
          subtitle: Text(
            e.startedAt != null && e.endedAt != null
                ? '${DateFormat('dd.MM HH:mm').format(e.startedAt!)} – '
                    '${DateFormat('dd.MM HH:mm').format(e.endedAt!)}'
                : DateFormat('dd.MM HH:mm').format(e.date),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Изменить сессию',
                onPressed: () => _editLog(e),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Удалить сессию',
                onPressed: () => _removeLog(e),
              ),
            ],
          ),
        ),
      if (logs.length > 20)
        Text(
          'Показаны последние 20 из ${logs.length}.',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
    ];
  }

  /// Ищет запись TrackedActivity для этого узла по trackingId
  /// (TrackedActivity.nodeId исторически хранит именно trackingId, см. #79).
  TrackedActivity? _findTrackedActivity(AppState appState) {
    for (final a in appState.trackedActivities) {
      if (a.nodeId == _node.trackingId) {
        return a;
      }
    }
    return null;
  }

  void _quickAddToTracking(AppState appState, TrackedActivity? existing) {
    if (existing != null) {
      // Уже была запись, но неактивна (снята с отслеживания ранее) — включаем обратно.
      final updated = TrackedActivity(
        id: existing.id,
        nodeId: existing.nodeId,
        name: existing.name,
        colorValue: existing.colorValue,
        stepType: existing.stepType,
        isActive: true,
        isRoutine: existing.isRoutine,
        order: existing.order,
        timeTrackingEnabled:
            existing.timeTrackingEnabled || _node.isTimeTrackingEnabled,
      );
      appState.updateTrackedActivity(existing.id, updated);
    } else {
      final activities = appState.trackedActivities;
      final maxOrder = activities.isEmpty
          ? 0
          : activities.map((a) => a.order).reduce((a, b) => a > b ? a : b);
      final newActivity = TrackedActivity(
        nodeId: _node.trackingId,
        name: _node.name,
        colorValue: Colors.blue.toARGB32(),
        stepType: _node.stepType,
        isActive: true,
        order: maxOrder + 1,
        timeTrackingEnabled: _node.isTimeTrackingEnabled ||
            appState.historyBox.values.any(
              (entry) =>
                  entry.trackingId == _node.trackingId &&
                  entry.stepType == 'duration',
            ),
      );
      appState.addTrackedActivity(newActivity);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Добавлено в отслеживаемые (heatmap). Цвет можно изменить в разделе "Отслеживаемые задачи".',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasChildren = _node.children.isNotEmpty;
    // Own progress is shown for leaves and for parents that keep it (#111).
    final bool isLeaf = _node.hasOwnProgress;
    final bool isSingle = _node.stepType == 'single';
    final bool isTrackable = isLeaf && !_node.excludeFromHistory;

    final appState = context.watch<AppState>();
    final trackedActivity = isTrackable ? _findTrackedActivity(appState) : null;
    final bool isTracked = trackedActivity != null && trackedActivity.isActive;

    return Scaffold(
      appBar: AppBar(title: Text(_node.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Название: ${_node.name}',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Тип: ${isLeaf ? (isSingle ? 'Одиночный чекбокс' : 'Пошаговый') : 'Папка'}',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    if (hasChildren && isLeaf)
                      Text(
                        'Подзадач: ${_node.children.length}. Общий прогресс: '
                        '${_node.completedLeaves}/${_node.totalLeaves}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    if (_node.excludeFromHistory)
                      const Text(
                        ' (не учитывается в прогрессе)',
                        style: TextStyle(fontSize: 14, color: Colors.orange),
                      ),
                    if (isTrackable) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            isTracked ? Icons.show_chart : Icons.visibility_off,
                            size: 18,
                            color: isTracked ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isTracked
                                ? 'Отслеживается на heatmap'
                                : 'Не отслеживается на heatmap',
                            style: TextStyle(
                              fontSize: 13,
                              color: isTracked ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      if (!isTracked)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                _quickAddToTracking(appState, trackedActivity),
                            icon: const Icon(Icons.add_chart, size: 18),
                            label: const Text('Добавить в отслеживаемые'),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (isLeaf && isSingle) ...[
              const Text(
                'Прогресс:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              CheckboxListTile(
                title: const Text('Выполнено'),
                value: _node.completed,
                onChanged: _onToggle,
              ),
            ] else if (isLeaf) ...[
              const Text(
                'Прогресс:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text('Всего шагов: ${_node.totalSteps}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _tempSteps.toDouble(),
                      min: 0,
                      max: _node.totalSteps.toDouble(),
                      divisions: _node.totalSteps,
                      onChanged: _onSliderChanged,
                      onChangeEnd: _onSliderChangeEnd,
                    ),
                  ),
                  Text('$_tempSteps/${_node.totalSteps}'),
                ],
              ),
            ] else if (!isLeaf) ...[
              const Text(
                'Это папка. Нажмите "Назад", чтобы вернуться.',
                style: TextStyle(fontSize: 16),
              ),
            ],
            if (isLeaf) ...[
              const SizedBox(height: 20),
              const Text(
                'Учёт времени:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                durationProgressLabel(_node.loggedMinutes, _node.targetMinutes),
                style: TextStyle(
                  fontSize: 18,
                  color: _node.timeGoalReached ? Colors.green : null,
                ),
              ),
              if ((_node.targetMinutes ?? 0) > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_node.loggedMinutes / _node.targetMinutes!)
                      .clamp(0.0, 1.0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _node.timeGoalReached
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in const [5, 15, 30, 60])
                    ActionChip(
                      label: Text('+ ${formatDuration(m)}'),
                      onPressed: () => _addMinutes(m),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.edit, size: 16),
                    label: const Text('Своё…'),
                    onPressed: _addCustomMinutes,
                  ),
                ],
              ),
              ..._buildLogList(),
            ],
          ],
        ),
        ),
      ),
    );
  }
}