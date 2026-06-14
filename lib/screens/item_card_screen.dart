import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../models/standard_task.dart';
import '../providers/app_state.dart';
import 'editor_screen.dart';
import 'standard_tasks_picker_screen.dart';

class ItemCardScreen extends StatefulWidget {
  final Node node;
  final bool isNew;
  final bool quickAdd;

  const ItemCardScreen({
    super.key,
    required this.node,
    this.isNew = false,
    this.quickAdd = false,
  });

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
  bool _didSave = false;

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
    if (!_didSave) {
      if (widget.quickAdd) {
        Navigator.pop(context, null);
      } else {
        _saveOnDispose();
      }
    }
    super.dispose();
  }

  void _saveOnDispose() {
    final name = _nameController.text.trim();
    if (widget.isNew && name.isNotEmpty) {
      final existingId = _findExistingTrackingId(name);
      _workingCopy.trackingId = existingId;
    }
    _workingCopy.name = name;
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

  void _save() {
    _didSave = true;
    _saveOnDispose();
  }

  void _cancel() {
    Navigator.pop(context, null);
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

  void _pickFromStandard() async {
    final selected = await Navigator.push<StandardTask>(
      context,
      MaterialPageRoute(builder: (_) => const StandardTasksPickerScreen()),
    );
    if (selected != null) {
      final name = selected.name;
      final existingId = _findExistingTrackingId(name);
      setState(() {
        _nameController.text = name;
        _stepType = selected.stepType;
        _totalSteps = selected.stepType == 'stepByStep' ? selected.totalSteps : 1;
        _excludeFromHistory = selected.excludeFromHistory;
        _totalStepsController.text = _totalSteps.toString();
        _completedSteps = 0;
        _workingCopy.trackingId = existingId;
      });
    }
  }

  /// Поиск существующего trackingId для задачи с таким же именем
  String _findExistingTrackingId(String name) {
    final appState = context.read<AppState>();
    final allNodes = <Node>[];
    allNodes.addAll(appState.books);
    allNodes.addAll(appState.plans);
    allNodes.addAll(appState.templates);

    List<Node> collectLeaves(List<Node> nodes) {
      final leaves = <Node>[];
      for (var node in nodes) {
        if (node.children.isEmpty && node.stepType != 'folder') {
          leaves.add(node);
        } else {
          leaves.addAll(collectLeaves(node.children));
        }
      }
      return leaves;
    }

    final allLeaves = collectLeaves(allNodes);
    for (var node in allLeaves) {
      if (node.name.toLowerCase() == name.toLowerCase() && node.trackingId.isNotEmpty) {
        return node.trackingId;
      }
    }
    return const Uuid().v4();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFolder = _stepType == 'folder';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Новый элемент' : 'Редактировать элемент'),
        leading: widget.quickAdd
            ? IconButton(icon: const Icon(Icons.close), onPressed: _cancel)
            : null,
        actions: [
          if (widget.isNew)
            IconButton(
              icon: const Icon(Icons.list_alt),
              onPressed: _pickFromStandard,
              tooltip: 'Выбрать из стандартных',
            ),
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                if (widget.isNew && value.trim().isNotEmpty) {
                  final existingId = _findExistingTrackingId(value.trim());
                  _workingCopy.trackingId = existingId;
                }
              },
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Radio<String>(
                    value: 'single',
                    groupValue: _stepType,
                    onChanged: _onStepTypeChanged,
                  ),
                  const Text('Одиночный чекбокс'),
                  const SizedBox(width: 24),
                  Radio<String>(
                    value: 'stepByStep',
                    groupValue: _stepType,
                    onChanged: _onStepTypeChanged,
                  ),
                  const Text('Пошаговый'),
                ],
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