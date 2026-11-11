import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/app_state.dart';
import '../utils/tracking_choices.dart';

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
      if (node.isTrackableTask) result.add(node);
      result.addAll(_collectLeafNodesFromPlans(node.children));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final allLeafNodes = _collectLeafNodesFromPlans(appState.plans);

    // Стандартные задачи с их актуальным описанием (тип, число шагов), затем
    // задачи из планов, которых нет среди стандартных (по trackingId) (#173).
    final choices = trackingChoices(
      standardTasks: appState.standardTasks,
      planLeaves: allLeafNodes,
    );

    // Фильтрация по поисковому запросу
    final filteredNodes = _searchQuery.isEmpty
        ? choices
        : choices.where((c) =>
        c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

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
              elevation: WidgetStateProperty.all(0),
              shape: WidgetStateProperty.all(
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
        child: Text('Нет доступных задач.\nСоздайте стандартную задачу или не-рутинную задачу в плане.'),
      )
          : ListView.builder(
        itemCount: filteredNodes.length,
        itemBuilder: (ctx, index) {
          final choice = filteredNodes[index];
          return ListTile(
            title: Text(choice.name),
            subtitle: Text(choice.description),
            onTap: () => Navigator.pop(context, choice.toNode()),
          );
        },
      ),
    );
  }
}