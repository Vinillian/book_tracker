import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class StandardTasksPickerScreen extends StatelessWidget {
  const StandardTasksPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final tasks = appState.standardTasks;

    return Scaffold(
      appBar: AppBar(title: const Text('Выберите задачу')),
      body: tasks.isEmpty
          ? const Center(child: Text('Нет стандартных задач. Создайте их в меню.'))
          : ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (ctx, index) {
          final task = tasks[index];
          return ListTile(
            title: Text(task.name),
            subtitle: Text(
              task.stepType == 'single'
                  ? 'Одиночный чекбокс'
                  : 'Пошаговый (${task.totalSteps} шагов)',
            ),
            onTap: () => Navigator.pop(context, task),
          );
        },
      ),
    );
  }
}