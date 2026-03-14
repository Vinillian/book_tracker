import 'package:flutter/material.dart';
import '../models/node.dart';
import '../utils/history_service.dart';

class ViewItemScreen extends StatefulWidget {
  final String bookId;
  final Node node;
  final VoidCallback onNodeUpdated;

  const ViewItemScreen({
    super.key,
    required this.bookId,
    required this.node,
    required this.onNodeUpdated,
  });

  @override
  State<ViewItemScreen> createState() => _ViewItemScreenState();
}

class _ViewItemScreenState extends State<ViewItemScreen> {
  late Node _node;

  @override
  void initState() {
    super.initState();
    _node = widget.node;
  }

  void _onToggle(bool? value) {
    setState(() {
      _node.completed = value!;
    });
    HistoryService.recordToggle(
      bookId: widget.bookId,
      node: _node,
      newValue: _node.completed,
    );
    widget.onNodeUpdated();
  }

  void _onSliderChanged(double value) {
    setState(() {
      _node.completedSteps = value.round();
    });
  }

  void _onSliderChangeEnd(double value) {
    HistoryService.recordStepChange(
      bookId: widget.bookId,
      node: _node,
      newSteps: _node.completedSteps,
    );
    widget.onNodeUpdated();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLeaf = _node.children.isEmpty;
    final bool isSingle = _node.stepType == 'single';

    return Scaffold(
      appBar: AppBar(title: Text(_node.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Название: ${_node.name}',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Тип: ${isLeaf ? (isSingle ? 'Одиночный чекбокс' : 'Пошаговый') : 'Папка'}',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (isLeaf && isSingle) ...[
              const Text(
                'Прогресс:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              CheckboxListTile(
                title: const Text('Выполнено'),
                value: _node.completed,
                onChanged: _onToggle,
              ),
            ] else if (isLeaf && !isSingle) ...[
              const Text(
                'Прогресс:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text('Всего шагов: ${_node.totalSteps}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _node.completedSteps.toDouble(),
                      min: 0,
                      max: _node.totalSteps.toDouble(),
                      divisions: _node.totalSteps,
                      onChanged: _onSliderChanged,
                      onChangeEnd: _onSliderChangeEnd,
                    ),
                  ),
                  Text('${_node.completedSteps}/${_node.totalSteps}'),
                ],
              ),
            ] else if (!isLeaf) ...[
              const Text(
                'Это папка. Нажмите "Назад", чтобы вернуться.',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
