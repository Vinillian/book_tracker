import 'package:flutter/material.dart';
import '../models/node.dart';
import 'editor_screen.dart';

class ItemCardScreen extends StatefulWidget {
  final Node node;
  final bool isNew;

  const ItemCardScreen({super.key, required this.node, this.isNew = false});

  @override
  State<ItemCardScreen> createState() => _ItemCardScreenState();
}

class _ItemCardScreenState extends State<ItemCardScreen> {
  late Node _node;
  late TextEditingController _nameController;
  late TextEditingController _totalStepsController;
  late String _stepType;
  late int _totalSteps;
  late int _completedSteps;

  @override
  void initState() {
    super.initState();
    _node = widget.node;
    _nameController = TextEditingController(text: _node.name);
    _stepType = _node.stepType;
    _totalSteps = _node.totalSteps;
    _completedSteps = _node.completedSteps;
    _totalStepsController = TextEditingController(text: _totalSteps.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _totalStepsController.dispose();
    super.dispose();
  }

  void _save() {
    _node.name = _nameController.text;
    _node.stepType = _stepType;
    _node.totalSteps = _totalSteps;
    if (_stepType == 'single') {
      _node.completed = _completedSteps > 0;
      _node.completedSteps = 0;
    } else {
      _node.completedSteps = _completedSteps.clamp(0, _totalSteps);
      _node.completed = false;
    }
    Navigator.pop(context, _node);
  }

  void _openStructureEditor() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditorScreen(node: _node)),
    );
    if (updated != null) {
      setState(() {
        _node = updated;
        _nameController.text = _node.name;
        _totalSteps = _node.totalSteps;
        _completedSteps = _node.completedSteps;
        _totalStepsController.text = _totalSteps.toString();
      });
    }
  }

  void _updateTotalSteps(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) {
      setState(() {
        _totalSteps = parsed;
        if (_completedSteps > _totalSteps) {
          _completedSteps = _totalSteps;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLeaf = _node.children.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Новый элемент' : 'Редактировать элемент'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (!isLeaf) ...[
              const Text('Тип: Папка', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _openStructureEditor,
                  icon: const Icon(Icons.folder),
                  label: const Text('Редактировать структуру'),
                ),
              ),
            ] else ...[
              const Text(
                'Тип прогресса:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              RadioListTile<String>(
                title: const Text('Одиночный чекбокс'),
                value: 'single',
                groupValue: _stepType,
                onChanged: (value) {
                  setState(() {
                    _stepType = value!;
                    _totalSteps = 1;
                    _completedSteps = 0;
                    _totalStepsController.text = _totalSteps.toString();
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Пошаговый'),
                value: 'stepByStep',
                groupValue: _stepType,
                onChanged: (value) {
                  setState(() {
                    _stepType = value!;
                    _totalSteps = 3;
                    _completedSteps = 0;
                    _totalStepsController.text = _totalSteps.toString();
                  });
                },
              ),
              if (_stepType == 'stepByStep') ...[
                const SizedBox(height: 16),
                const Text(
                  'Количество шагов:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _totalStepsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Введите число',
                  ),
                  onChanged: _updateTotalSteps,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Выполнено шагов:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _completedSteps.toDouble(),
                        min: 0,
                        max: _totalSteps.toDouble(),
                        divisions: _totalSteps,
                        onChanged: (value) {
                          setState(() {
                            _completedSteps = value.round();
                          });
                        },
                      ),
                    ),
                    Text('$_completedSteps'),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
