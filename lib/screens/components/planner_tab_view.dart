import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/node.dart';
import '../../providers/app_state.dart';
import '../../utils/delete_with_undo.dart';
import '../../utils/plan_date.dart';
import '../editor_screen.dart';
import '../book_screen.dart';

class PlannerTabView extends StatelessWidget {
  const PlannerTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final plans = appState.plans;

    if (plans.isEmpty) {
      return const Center(
        child: Text('Нет планов. Нажмите "+" в шапке, чтобы создать день.'),
      );
    }

    final sorted = List<Node>.from(plans)
      ..sort((a, b) {
        final dateA = planDateOf(a);
        final dateB = planDateOf(b);
        if (dateA != null && dateB != null) return dateB.compareTo(dateA);
        if (dateA != null) return -1;
        if (dateB != null) return 1;
        return b.name.compareTo(a.name);
      });

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final plan = sorted[index];
        final key = appState.getKeyForNode(plan);
        final date = planDateOf(plan);
        final dateStr = date == null ? null : DateFormat('dd.MM.yyyy').format(date);
        final tasks = 'Задач: ${plan.nonRoutineLeafCount}';

        return Dismissible(
          key: ValueKey(plan.id),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.only(right: 20),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => deleteNodeWithUndo(context, plan),
          child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(plan.name),
            subtitle: Text(
              dateStr != null && dateStr != plan.name ? '$dateStr · $tasks' : tasks,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editPlan(context, key, plan),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => deleteNodeWithUndo(context, plan),
                ),
              ],
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookScreen(
                    node: plan,
                    onNodeUpdated: () => appState.updateNode(key, plan),
                  ),
                ),
              );
            },
          ),
          ),
        );
      },
    );
  }

  void _editPlan(BuildContext context, dynamic key, Node plan) async {
    final appState = context.read<AppState>();
    final updated = await Navigator.push<Node>(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(node: plan.deepCopy())),
    );
    if (updated != null && context.mounted) {
      appState.updateNode(key, updated);
    }
  }
}
