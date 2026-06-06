import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/standard_task.dart';
import '../providers/app_state.dart';

class StandardTasksScreen extends StatefulWidget {
  const StandardTasksScreen({super.key});

  @override
  State<StandardTasksScreen> createState() => _StandardTasksScreenState();
}

class _StandardTasksScreenState extends State<StandardTasksScreen> {
  void _addTask() {
    final newTask = StandardTask(name: '', stepType: 'single');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StandardTaskEditorScreen(task: newTask, isNew: true),
      ),
    );
  }

  void _editTask(StandardTask task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StandardTaskEditorScreen(task: task, isNew: false),
      ),
    );
  }

  void _deleteTask(StandardTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить задачу?'),
        content: Text('Задача "${task.name}" будет удалена.'),
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
      context.read<AppState>().deleteStandardTask(task.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final tasks = appState.standardTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Стандартные задачи'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addTask,
            tooltip: 'Добавить задачу',
          ),
        ],
      ),
      body: tasks.isEmpty
          ? const Center(
        child: Text('Нет стандартных задач. Нажмите + для создания.'),
      )
          : ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (ctx, index) {
          final task = tasks[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              title: Text(task.name),
              subtitle: Text(
                task.stepType == 'single'
                    ? 'Одиночный чекбокс'
                    : 'Пошаговый (${task.totalSteps} шагов)',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editTask(task),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteTask(task),
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

class StandardTaskEditorScreen extends StatefulWidget {
  final StandardTask task;
  final bool isNew;

  const StandardTaskEditorScreen({super.key, required this.task, required this.isNew});

  @override
  State<StandardTaskEditorScreen> createState() => _StandardTaskEditorScreenState();
}

class _StandardTaskEditorScreenState extends State<StandardTaskEditorScreen> {
  late TextEditingController _nameController;
  late String _stepType;
  late int _totalSteps;
  late bool _excludeFromHistory;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task.name);
    _stepType = widget.task.stepType;
    _totalSteps = widget.task.totalSteps;
    _excludeFromHistory = widget.task.excludeFromHistory;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название')),
      );
      return;
    }
    final updatedTask = StandardTask(
      id: widget.task.id,
      name: name,
      stepType: _stepType,
      totalSteps: _stepType == 'stepByStep' ? _totalSteps : 1,
      excludeFromHistory: _excludeFromHistory,
    );
    final appState = context.read<AppState>();
    if (widget.isNew) {
      appState.addStandardTask(updatedTask);
    } else {
      appState.updateStandardTask(widget.task.id, updatedTask);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Новая задача' : 'Редактировать'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text(
              'Тип прогресса:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            RadioListTile<String>(
              title: const Text('Одиночный чекбокс'),
              value: 'single',
              groupValue: _stepType,
              onChanged: (value) => setState(() => _stepType = value!),
            ),
            RadioListTile<String>(
              title: const Text('Пошаговый'),
              value: 'stepByStep',
              groupValue: _stepType,
              onChanged: (value) => setState(() => _stepType = value!),
            ),
            if (_stepType == 'stepByStep') ...[
              const SizedBox(height: 16),
              const Text(
                'Количество шагов:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed > 0) {
                    setState(() => _totalSteps = parsed);
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Не учитывать в прогрессе (рутина)'),
              value: _excludeFromHistory,
              onChanged: (value) => setState(() => _excludeFromHistory = value ?? false),
            ),
          ],
        ),
      ),
    );
  }
}