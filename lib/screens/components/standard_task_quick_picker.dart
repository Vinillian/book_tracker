import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/standard_task.dart';
import '../../providers/app_state.dart';

/// Bottom sheet with a searchable list of standard tasks. Tapping a task calls
/// [onPick] right away and the sheet stays open, so several tasks can be added
/// in a row (#109).
Future<void> showStandardTaskQuickPicker(
  BuildContext context, {
  required ValueChanged<StandardTask> onPick,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.6,
        child: _StandardTaskQuickPicker(onPick: onPick),
      ),
    ),
  );
}

class _StandardTaskQuickPicker extends StatefulWidget {
  final ValueChanged<StandardTask> onPick;

  const _StandardTaskQuickPicker({required this.onPick});

  @override
  State<_StandardTaskQuickPicker> createState() =>
      _StandardTaskQuickPickerState();
}

class _StandardTaskQuickPickerState extends State<_StandardTaskQuickPicker> {
  String _query = '';
  // How many times each task was added while the sheet is open.
  final Map<String, int> _added = {};

  @override
  Widget build(BuildContext context) {
    final all = context.watch<AppState>().standardTasks;
    final q = _query.trim().toLowerCase();
    final tasks = q.isEmpty
        ? all
        : all.where((t) => t.name.toLowerCase().contains(q)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Поиск задач...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Text(
                    all.isEmpty
                        ? 'Нет стандартных задач. Создайте их в меню.'
                        : 'Ничего не найдено',
                  ),
                )
              : ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (ctx, i) {
                    final task = tasks[i];
                    final count = _added[task.id] ?? 0;
                    return ListTile(
                      title: Text(task.name),
                      subtitle: Text(
                        task.stepType == 'single'
                            ? 'Одиночный чекбокс'
                            : 'Пошаговый (${task.totalSteps} шагов)',
                      ),
                      trailing: count == 0
                          ? const Icon(Icons.add)
                          : Text(
                              '✓ ×$count',
                              style: TextStyle(
                                color: Theme.of(ctx).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      onTap: () {
                        widget.onPick(task);
                        setState(() => _added[task.id] = count + 1);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
