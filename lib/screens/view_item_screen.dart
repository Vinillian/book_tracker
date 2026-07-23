import 'package:flutter/material.dart';
import '../models/node.dart';
import '../services/history_service.dart';

class ViewItemScreen extends StatefulWidget {
  final String bookId;
  final Node node;
  final VoidCallback onNodeUpdated;
  final DateTime? targetDate;

  const ViewItemScreen({
    super.key,
    required this.bookId,
    required this.node,
    required this.onNodeUpdated,
    this.targetDate,
  });

  @override
  State<ViewItemScreen> createState() => _ViewItemScreenState();
}

class _ViewItemScreenState extends State<ViewItemScreen> {
  late Node _node;
  late int _tempSteps;

  @override
  void initState() {
    super.initState();
    _node = widget.node;
    _tempSteps = _node.completedSteps;
  }

  void _onToggle(bool? value) {
    final newValue = value ?? false;
    setState(() {
      _node.completed = newValue;
    });
    if (!_node.excludeFromHistory) {
      HistoryService.recordUniqueToggle(
        bookId: widget.bookId,
        node: _node,
        newValue: newValue,
        // targetDate intentionally omitted – uses DateTime.now()
      );
    }
    widget.onNodeUpdated();
  }

  void _onSliderChanged(double value) {
    setState(() {
      _tempSteps = value.round();
    });
  }

  void _onSliderChangeEnd(double value) {
    final newSteps = value.round();
    final oldSteps = _node.completedSteps;
    if (newSteps != oldSteps) {
      setState(() {
        _node.completedSteps = newSteps;
        _tempSteps = newSteps;
      });
      if (!_node.excludeFromHistory) {
        HistoryService.recordUniqueProgress(
          bookId: widget.bookId,
          node: _node,
          newSteps: newSteps,
          // targetDate intentionally omitted – uses DateTime.now()
        );
      }
      widget.onNodeUpdated();
    }
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
                    if (_node.excludeFromHistory)
                      const Text(
                        ' (не учитывается в прогрессе)',
                        style: TextStyle(fontSize: 14, color: Colors.orange),
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
                      value: _tempSteps.toDouble(),
                      min: 0,
                      max: _node.totalSteps.toDouble(),
                      divisions: _node.totalSteps,
                      onChanged: _onSliderChanged,
                      onChangeEnd: _onSliderChangeEnd,
                    ),
                  ),
                  Text('$_tempSteps/${_node.totalSteps}'),
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