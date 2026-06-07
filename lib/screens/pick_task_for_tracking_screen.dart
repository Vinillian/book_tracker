import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/app_state.dart';

class PickTaskForTrackingScreen extends StatelessWidget {
  const PickTaskForTrackingScreen({super.key});

  List<Node> _collectLeafNodesFromPlans(List<Node> nodes) {
    final List<Node> result = [];
    for (var node in nodes) {
      if (node.excludeFromHistory) continue;
      if (node.children.isEmpty && node.stepType != 'folder') {
        result.add(node);
      } else {
        result.addAll(_collectLeafNodesFromPlans(node.children));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final plans = appState.plans;
    final allLeafNodes = _collectLeafNodesFromPlans(plans);

    // Группируем по trackingId (постоянный идентификатор)
    final uniqueMap = <String, Node>{};
    for (var node in allLeafNodes) {
      if (!uniqueMap.containsKey(node.trackingId)) {
        uniqueMap[node.trackingId] = node;
      }
    }
    final uniqueNodes = uniqueMap.values.toList();
    uniqueNodes.sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(title: const Text('Выберите задачу')),
      body: uniqueNodes.isEmpty
          ? const Center(
        child: Text('Нет доступных задач. Создайте не-рутинные задачи в планах.'),
      )
          : ListView.builder(
        itemCount: uniqueNodes.length,
        itemBuilder: (ctx, index) {
          final node = uniqueNodes[index];
          return ListTile(
            title: Text(node.name),
            subtitle: Text(
              node.stepType == 'single'
                  ? 'Одиночный чекбокс'
                  : 'Пошаговая (${node.totalSteps} шагов)',
            ),
            onTap: () => Navigator.pop(context, node),
          );
        },
      ),
    );
  }
}