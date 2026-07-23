import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../models/tracked_activity.dart';
import '../providers/app_state.dart';
import 'pick_task_for_tracking_screen.dart';

class TrackedActivitiesScreen extends StatefulWidget {
  const TrackedActivitiesScreen({super.key});

  @override
  State<TrackedActivitiesScreen> createState() => _TrackedActivitiesScreenState();
}

class _TrackedActivitiesScreenState extends State<TrackedActivitiesScreen> {
  final List<Color> _presetColors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
    Colors.lime,
    Colors.brown,
  ];

  // Сохраняем локальную копию для перетаскивания, чтобы обновлять UI
  late List<TrackedActivity> _activities;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  void _loadActivities() {
    final appState = Provider.of<AppState>(context, listen: false);
    _activities = appState.trackedActivities.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> _addActivity() async {
    final Node? selectedNode = await Navigator.push<Node>(
      context,
      MaterialPageRoute(builder: (_) => const PickTaskForTrackingScreen()),
    );
    if (!mounted) return;
    if (selectedNode == null) return;

    final appState = Provider.of<AppState>(context, listen: false);

    // Проверяем дубликат
    TrackedActivity? existing;
    for (final a in appState.trackedActivities) {
      if (a.nodeId == selectedNode.trackingId) {
        existing = a;
        break;
      }
    }

    if (existing != null) {
      if (!existing.isActive) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Задача включена обратно')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Задача уже отслеживается')),
        );
      }
      _loadActivities();
      setState(() {});
      return;
    }

    // Выбор цвета
    Color? selectedColor = await _showColorPicker(context);
    if (!mounted) return;
    if (selectedColor == null) return;

    // Максимальный order для новой задачи
    final maxOrder = _activities.isEmpty ? 0 : _activities.map((a) => a.order).reduce((a, b) => a > b ? a : b);
    final newOrder = maxOrder + 1;

    final newActivity = TrackedActivity(
      nodeId: selectedNode.trackingId,
      name: selectedNode.name,
      colorValue: selectedColor.toARGB32(),
      stepType: selectedNode.stepType,
      isActive: true,
      order: newOrder,
    );

    appState.addTrackedActivity(newActivity);
    _loadActivities();
    setState(() {});
  }

  Future<Color?> _showColorPicker(BuildContext context) async {
    return showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выберите цвет'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presetColors.map((color) {
            return GestureDetector(
              onTap: () => Navigator.pop(ctx, color),
              child: CircleAvatar(
                backgroundColor: color,
                radius: 25,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _changeColor(TrackedActivity activity) async {
    final Color? newColor = await _showColorPicker(context);
    if (!mounted) return;
    if (newColor == null) return;

    final appState = Provider.of<AppState>(context, listen: false);
    final updated = TrackedActivity(
      id: activity.id,
      nodeId: activity.nodeId,
      name: activity.name,
      colorValue: newColor.toARGB32(),
      stepType: activity.stepType,
      isActive: activity.isActive,
      isRoutine: activity.isRoutine,
      order: activity.order,
    );
    appState.updateTrackedActivity(activity.id, updated);
    _loadActivities();
    setState(() {});
  }

  void _toggleActive(TrackedActivity activity, bool value) {
    final appState = Provider.of<AppState>(context, listen: false);
    final updated = TrackedActivity(
      id: activity.id,
      nodeId: activity.nodeId,
      name: activity.name,
      colorValue: activity.colorValue,
      stepType: activity.stepType,
      isActive: value,
      isRoutine: activity.isRoutine,
      order: activity.order,
    );
    appState.updateTrackedActivity(activity.id, updated);
    _loadActivities();
    setState(() {});
  }

  void _deleteActivity(TrackedActivity activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить задачу?'),
        content: Text('Задача "${activity.name}" больше не будет отслеживаться.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.deleteTrackedActivity(activity.id);
      _loadActivities();
      setState(() {});
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _activities.removeAt(oldIndex);
    _activities.insert(newIndex, item);

    // Обновляем order для всех элементов
    final appState = Provider.of<AppState>(context, listen: false);
    for (int i = 0; i < _activities.length; i++) {
      final activity = _activities[i];
      if (activity.order != i) {
        final updated = TrackedActivity(
          id: activity.id,
          nodeId: activity.nodeId,
          name: activity.name,
          colorValue: activity.colorValue,
          stepType: activity.stepType,
          isActive: activity.isActive,
          isRoutine: activity.isRoutine,
          order: i,
        );
        appState.updateTrackedActivity(activity.id, updated);
      }
    }
    // Перезагружаем список, чтобы синхронизировать с боксом
    _loadActivities();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Подписываемся на изменения в боксе, чтобы обновлять список
    return Consumer<AppState>(
      builder: (context, appState, _) {
        // Если список изменился извне, обновляем локальную копию
        final currentActivities = appState.trackedActivities.toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        if (_activities.length != currentActivities.length ||
            _activities.any((a) => !currentActivities.any((b) => b.id == a.id))) {
          _activities = currentActivities;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Отслеживаемые задачи'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _addActivity,
              ),
            ],
          ),
          body: _activities.isEmpty
              ? const Center(
            child: Text('Нет отслеживаемых задач. Нажмите + для добавления.'),
          )
              : ReorderableListView.builder(
            itemCount: _activities.length,
            onReorder: _onReorder,
            itemBuilder: (ctx, index) {
              final activity = _activities[index];
              return Card(
                key: Key(activity.id),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: GestureDetector(
                    onTap: () => _changeColor(activity),
                    child: CircleAvatar(
                      backgroundColor: Color(activity.colorValue),
                      child: const Icon(Icons.color_lens, color: Colors.white, size: 18),
                    ),
                  ),
                  title: Text(activity.name),
                  subtitle: Text(
                    activity.stepType == 'single' ? 'Одиночная' : 'Пошаговая',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: activity.isActive,
                        onChanged: (value) => _toggleActive(activity, value),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteActivity(activity),
                      ),
                      const ReorderableDragStartListener(
                        index: 0, // будет переопределено
                        child: Icon(Icons.drag_handle),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}