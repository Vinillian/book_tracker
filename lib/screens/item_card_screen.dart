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
  late Node _workingCopy;
  late TextEditingController _nameController;
  late TextEditingController _totalStepsController;
  late String _stepType;
  late int _totalSteps;
  late int _completedSteps;
  late bool _excludeFromHistory;

  @override
  void initState() {
    super.initState();
    _workingCopy = widget.isNew ? widget.node : widget.node.deepCopy();
    _nameController = TextEditingController(text: _workingCopy.name);
    _stepType = _workingCopy.stepType;
    _totalSteps = _workingCopy.totalSteps;
    _completedSteps = _workingCopy.completedSteps;
    _excludeFromHistory = _workingCopy.excludeFromHistory;
    _totalStepsController = TextEditingController(text: _totalSteps.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _totalStepsController.dispose();
    super.dispose();
  }

  void _save() {
    _workingCopy.name = _nameController.text;
    _workingCopy.stepType = _stepType;
    _workingCopy.totalSteps = _totalSteps;
    _workingCopy.excludeFromHistory = _excludeFromHistory;
    if (_stepType == 'single') {
      _workingCopy.completed = _completedSteps > 0;
      _workingCopy.completedSteps = 0;
    } else if (_stepType == 'stepByStep') {
      _workingCopy.completedSteps = _completedSteps.clamp(0, _totalSteps);
      _workingCopy.completed = false;
    }
    Navigator.pop(context, _workingCopy);
  }

  void _openStructureEditor() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(node: _workingCopy.deepCopy()),
      ),
    );
    if (updated != null) {
      setState(() {
        _workingCopy = updated;
        _nameController.text = _workingCopy.name;
        _stepType = _workingCopy.stepType;
        _totalSteps = _workingCopy.totalSteps;
        _completedSteps = _workingCopy.completedSteps;
        _excludeFromHistory = _workingCopy.excludeFromHistory;
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

  void _onStepTypeChanged(String? newType) {
    if (newType == null || newType == _stepType) return;
    if (_workingCopy.children.isNotEmpty && newType != 'folder') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Подтверждение'),
          content: const Text(
            'Изменение типа на лист приведёт к удалению всех вложенных элементов. Продолжить?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _stepType = newType;
                  _workingCopy.children.clear();
                  if (newType == 'single') {
                    _totalSteps = 1;
                    _completedSteps = 0;
                  } else if (newType == 'stepByStep') {
                    _totalSteps = 3;
                    _completedSteps = 0;
                  }
                  _totalStepsController.text = _totalSteps.toString();
                });
              },
              child: const Text('Продолжить'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _stepType = newType;
        if (newType == 'single') {
          _totalSteps = 1;
          _completedSteps = 0;
        } else if (newType == 'stepByStep') {
          _totalSteps = 3;
          _completedSteps = 0;
        } else if (newType == 'folder') {
          _totalSteps = 1;
          _completedSteps = 0;
        }
        _totalStepsController.text = _totalSteps.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isFolder = _stepType == 'folder';

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
            if (isFolder) ...[
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
                onChanged: _onStepTypeChanged,
              ),
              RadioListTile<String>(
                title: const Text('Пошаговый'),
                value: 'stepByStep',
                groupValue: _stepType,
                onChanged: _onStepTypeChanged,
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
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Не учитывать в прогрессе (рутина)'),
                value: _excludeFromHistory,
                onChanged: (value) {
                  setState(() {
                    _excludeFromHistory = value ?? false;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}