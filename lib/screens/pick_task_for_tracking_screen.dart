import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/app_state.dart';

class PickTaskForTrackingScreen extends StatefulWidget {
  const PickTaskForTrackingScreen({super.key});

  @override
  State<PickTaskForTrackingScreen> createState() => _PickTaskForTrackingScreenState();
}

class _PickTaskForTrackingScreenState extends State<PickTaskForTrackingScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

    // Группируем по trackingId
    final uniqueMap = <String, Node>{};
    for (var node in allLeafNodes) {
      if (!uniqueMap.containsKey(node.trackingId)) {
        uniqueMap[node.trackingId] = node;
      }
    }
    final allUniqueNodes = uniqueMap.values.toList();
    allUniqueNodes.sort((a, b) => a.name.compareTo(b.name));

    // Фильтрация по поисковому запросу
    final filteredNodes = _searchQuery.isEmpty
        ? allUniqueNodes
        : allUniqueNodes.where((node) =>
        node.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите задачу'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
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
      body: filteredNodes.isEmpty
          ? const Center(
        child: Text('Нет доступных задач.\nСоздайте не-рутинные задачи в планах.'),
      )
          : ListView.builder(
        itemCount: filteredNodes.length,
        itemBuilder: (ctx, index) {
          final node = filteredNodes[index];
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