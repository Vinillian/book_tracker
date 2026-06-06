import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tracked_activity.dart';
import '../providers/app_state.dart';

class TrackedActivitiesScreen extends StatefulWidget {
  const TrackedActivitiesScreen({super.key});

  @override
  State<TrackedActivitiesScreen> createState() => _TrackedActivitiesScreenState();
}

class _TrackedActivitiesScreenState extends State<TrackedActivitiesScreen> {
  void _addActivity() {
    // Заглушка для будущей реализации
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить задачу'),
        content: const Text('Выбор задачи будет реализован в следующей версии.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toggleActive(TrackedActivity activity, bool value) {
    final updated = TrackedActivity(
      id: activity.id,
      nodeId: activity.nodeId,
      name: activity.name,
      colorValue: activity.colorValue,
      stepType: activity.stepType,
      isActive: value,
    );
    Provider.of<AppState>(context, listen: false).updateTrackedActivity(activity.id, updated);
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
    if (confirmed == true && mounted) {
      Provider.of<AppState>(context, listen: false).deleteTrackedActivity(activity.id);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final activities = appState.trackedActivities;

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
      body: activities.isEmpty
          ? const Center(child: Text('Нет отслеживаемых задач. Нажмите + для добавления.'))
          : ListView.builder(
        itemCount: activities.length,
        itemBuilder: (ctx, index) {
          final activity = activities[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(activity.colorValue),
                child: const Icon(Icons.circle, color: Colors.white),
              ),
              title: Text(activity.name),
              subtitle: Text(activity.stepType == 'single' ? 'Одиночная' : 'Пошаговая'),
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}