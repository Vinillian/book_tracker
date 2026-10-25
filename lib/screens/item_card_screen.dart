import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../models/standard_task.dart';
import '../providers/app_state.dart';
import '../utils/day_part.dart';
import '../utils/format_minutes.dart';
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
  late TextEditingController _targetController;
  int? _targetMinutes;
  late String _stepType;
  late int _totalSteps;
  late int _completedSteps;
  late bool _excludeFromHistory;
  int? _startMinutes;
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
    _startMinutes = _workingCopy.startMinutes;
    _totalStepsController = TextEditingController(text: _totalSteps.toString());
    _targetMinutes = _workingCopy.targetMinutes;
    _targetController =
        TextEditingController(text: _targetMinutes?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _totalStepsController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _applyAndPop() {
    final name = _nameController.text.trim();
    if (widget.isNew && name.isNotEmpty) {
      final existingId = _findExistingTrackingId(name);
      _workingCopy.trackingId = existingId;
    }
    _workingCopy.name = name;
    _workingCopy.stepType = _stepType;
    _workingCopy.totalSteps = _totalSteps;
    _workingCopy.excludeFromHistory = _excludeFromHistory;
    _workingCopy.startMinutes = _startMinutes;
    if (_stepType == 'single') {
      _workingCopy.completed = _completedSteps > 0;
      _workingCopy.completedSteps = 0;
    } else if (_stepType == 'stepByStep') {
      _workingCopy.completedSteps = _completedSteps.clamp(0, _totalSteps);
      _workingCopy.completed = false;
    } else if (_stepType == 'duration') {
      // Logged minutes stay as they are; only the goal is edited here.
      _workingCopy.targetMinutes = _targetMinutes;
      _workingCopy.totalSteps = 1;
      _workingCopy.completedSteps = 0;
      _workingCopy.completed = false;
    }
    Navigator.pop(context, _workingCopy);
  }

  void _save() {
    if (_didSave) return;
    _didSave = true;
    _applyAndPop();
  }

  void _cancel() {
    if (_didSave) return;
    _didSave = true;
    Navigator.pop(context, null);
  }

  void _openStructureEditor() async {
    // Carry unsaved edits from the card into the copy the editor receives;
    // otherwise they are lost when the editor's result replaces the fields.
    _workingCopy.name = _nameController.text.trim();
    _workingCopy.stepType = _stepType;
    _workingCopy.totalSteps = _totalSteps;
    _workingCopy.excludeFromHistory = _excludeFromHistory;
    _workingCopy.startMinutes = _startMinutes;
    if (_stepType == 'stepByStep') {
      _workingCopy.completedSteps = _completedSteps.clamp(0, _totalSteps);
    }
    if (_stepType == 'duration') {
      _workingCopy.targetMinutes = _targetMinutes;
    }
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
        _startMinutes = _workingCopy.startMinutes;
        _totalStepsController.text = _totalSteps.toString();
        _targetMinutes = _workingCopy.targetMinutes;
        _targetController.text = _targetMinutes?.toString() ?? '';
      });
    }
  }

  Future<void> _pickStartTime() async {
    final initial = _startMinutes ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _startMinutes = picked.hour * 60 + picked.minute);
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

  void _updateTarget(String value) {
    final parsed = int.tryParse(value.trim());
    setState(() => _targetMinutes = (parsed != null && parsed > 0) ? parsed : null);
  }

  void _onStepTypeChanged(String? newType) {
    if (newType == null || newType == _stepType) return;
    // Switching between checkbox and steps keeps subtasks: since #111 a task
    // keeps its own progress next to them.
    setState(() {
      _stepType = newType;
      if (newType == 'single') {
        _totalSteps = 1;
        _completedSteps = 0;
      } else if (newType == 'stepByStep') {
        _totalSteps = 3;
        _completedSteps = 0;
      } else if (newType == 'duration' || newType == 'folder') {
        _totalSteps = 1;
        _completedSteps = 0;
      }
      _totalStepsController.text = _totalSteps.toString();
    });
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
        if (node.isTrackableTask) leaves.add(node);
        leaves.addAll(collectLeaves(node.children));
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
    // Системная «назад»: быстрое добавление отменяется, редактирование
    // существующей задачи сохраняется (раньше это делалось в dispose(),
    // когда результат уже некуда вернуть).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        widget.quickAdd ? _cancel() : _save();
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
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
            if (_workingCopy.category == null) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickStartTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        _startMinutes == null
                            ? 'Время начала: не задано'
                            : 'Время начала: ${formatMinutes(_startMinutes!)}',
                      ),
                    ),
                  ),
                  if (_startMinutes != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Убрать время',
                      onPressed: () => setState(() => _startMinutes = null),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
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
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'single', label: Text('Чекбокс')),
                    ButtonSegment(value: 'stepByStep', label: Text('Шаги')),
                    ButtonSegment(value: 'duration', label: Text('Длительность')),
                  ],
                  selected: {_stepType},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => _onStepTypeChanged(s.first),
                ),
              ),
              if (_stepType == 'duration') ...[
                const SizedBox(height: 16),
                const Text(
                  'Цель, минут (необязательно):',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _targetController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Без цели',
                    helperText: 'Выполнена, когда набрано нужное время; '
                        'без цели - когда записано любое время.',
                    helperMaxLines: 2,
                  ),
                  onChanged: _updateTarget,
                ),
                if (_workingCopy.loggedMinutes > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Записано: ${formatDuration(_workingCopy.loggedMinutes)}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
              ],
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
              OutlinedButton.icon(
                onPressed: _openStructureEditor,
                icon: const Icon(Icons.subdirectory_arrow_right),
                label: Text(
                  _workingCopy.children.isNotEmpty
                      ? 'Подзадачи (${_workingCopy.children.length})'
                      : 'Добавить подзадачи',
                ),
              ),
              if (_workingCopy.children.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Прогресс задачи и её подзадач считается вместе.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
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