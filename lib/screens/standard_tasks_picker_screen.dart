import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class StandardTasksPickerScreen extends StatefulWidget {
  const StandardTasksPickerScreen({super.key});

  @override
  State<StandardTasksPickerScreen> createState() =>
      _StandardTasksPickerScreenState();
}

class _StandardTasksPickerScreenState
    extends State<StandardTasksPickerScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final allTasks = appState.standardTasks;

    // Фильтрация по названию (регистронезависимая)
    final filteredTasks = _searchQuery.isEmpty
        ? allTasks
        : allTasks.where((task) =>
        task.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите задачу'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Поиск задач...',
              leading: const Icon(Icons.search),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              elevation: MaterialStateProperty.all(0),
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),
        ),
      ),
      body: filteredTasks.isEmpty
          ? Center(
        child: Text(
          allTasks.isEmpty
              ? 'Нет стандартных задач. Создайте их в меню.'
              : 'Ничего не найдено',
        ),
      )
          : ListView.builder(
        itemCount: filteredTasks.length,
        itemBuilder: (ctx, index) {
          final task = filteredTasks[index];
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