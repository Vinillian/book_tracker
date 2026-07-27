import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../models/tracked_activity.dart';
import '../providers/app_state.dart';
import '../services/history_service.dart';

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
          targetDate: _resolveEventDate(),
        );
      }
      widget.onNodeUpdated();
    }
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
    final bool isLeaf = _node.children.isEmpty;
    final bool isSingle = _node.stepType == 'single';
    final bool isTrackable = isLeaf && !_node.excludeFromHistory;

    final appState = context.watch<AppState>();
    final trackedActivity = isTrackable ? _findTrackedActivity(appState) : null;
    final bool isTracked = trackedActivity != null && trackedActivity.isActive;

    return Scaffold(
      appBar: AppBar(title: Text(_node.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
            ] else if (isLeaf && !isSingle) ...[
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
          ],
        ),
      ),
    );
  }
}