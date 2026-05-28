import 'package:flutter/material.dart';
import '../models/node.dart';
import 'item_card_screen.dart';

class EditorScreen extends StatefulWidget {
  final Node node;

  const EditorScreen({super.key, required this.node});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Node _workingCopy;
  late TextEditingController _nameController;
  String? _category;

  Set<int> _selectedIndices = {};
  bool _multiSelect = false;

  @override
  void initState() {
    super.initState();
    _workingCopy = widget.node.deepCopy();
    _nameController = TextEditingController(text: _workingCopy.name);
    _category = _workingCopy.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _saveOnDispose();
    super.dispose();
  }

  void _saveOnDispose() {
    _workingCopy.name = _nameController.text.trim();
    _workingCopy.category = _category;
    Navigator.pop(context, _workingCopy);
  }

  void _deleteSelected() {
    final sorted = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
    for (final i in sorted) {
      _workingCopy.children.removeAt(i);
    }
    setState(() {
      _multiSelect = false;
      _selectedIndices.clear();
    });
  }

  void _cancelSelection() {
    setState(() {
      _multiSelect = false;
      _selectedIndices.clear();
    });
  }

  void _addLeaf() async {
    bool keepAdding = true;
    while (keepAdding) {
      final newNode = Node.leaf('');
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ItemCardScreen(node: newNode, isNew: true, quickAdd: true),
        ),
      );
      if (!mounted) return;
      if (result is Node) {
        setState(() {
          _workingCopy.children.add(result);
        });
        final addAnother = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Лист сохранён'),
            content: const Text('Добавить ещё?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Нет'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Да'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (addAnother != true) {
          keepAdding = false;
        }
      } else {
        keepAdding = false;
      }
    }
  }

  void _addFolder() {
    final newNode = Node(name: '', children: [], stepType: 'folder');
    setState(() {
      _workingCopy.children.add(newNode);
    });
  }

  void _deleteChild(int index) {
    setState(() {
      _workingCopy.children.removeAt(index);
    });
  }

  void _editChild(int index) async {
    final child = _workingCopy.children[index];
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemCardScreen(node: child.deepCopy(), isNew: false),
      ),
    );
    if (!mounted) return;
    if (result != null && result is Node) {
      setState(() {
        _workingCopy.children[index] = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isRoot = widget.node.category != null;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: 'Название',
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          onChanged: (value) => _workingCopy.name = value,
        ),
        actions: [
          if (!_multiSelect)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                _workingCopy.name = _nameController.text.trim();
                _workingCopy.category = _category;
                Navigator.pop(context, _workingCopy);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (isRoot) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Категория',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'book', child: Text('Книга')),
                  DropdownMenuItem(value: 'planner', child: Text('План')),
                  DropdownMenuItem(value: 'template', child: Text('Шаблон')),
                ],
                onChanged: (value) => setState(() => _category = value),
              ),
            ),
            const Divider(),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Тип: ${_workingCopy.children.isEmpty ? "Лист (задача)" : "Папка (раздел)"}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Всего элементов: ${_workingCopy.totalLeaves}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                if (!_multiSelect)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'leaf') _addLeaf();
                      if (value == 'folder') _addFolder();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'leaf',
                        child: Text('Добавить лист'),
                      ),
                      PopupMenuItem(
                        value: 'folder',
                        child: Text('Добавить папку'),
                      ),
                    ],
                    icon: const Icon(Icons.add),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _workingCopy.children.isEmpty
                ? const Center(
                    child: Text(
                      'Нет дочерних элементов. Нажмите "+" для создания.',
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: _workingCopy.children.length,
                    onReorder: (oldIndex, newIndex) {
                      if (_multiSelect) return;
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _workingCopy.children.removeAt(oldIndex);
                        _workingCopy.children.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final child = _workingCopy.children[index];
                      final isSelected = _selectedIndices.contains(index);
                      return Card(
                        key: ValueKey(child),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: _multiSelect
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedIndices.add(index);
                                      } else {
                                        _selectedIndices.remove(index);
                                      }
                                    });
                                  },
                                )
                              : ReorderableDragStartListener(
                                  index: index,
                                  child: const Icon(Icons.drag_handle),
                                ),
                          title: Text(
                            child.name.isEmpty ? '[Без названия]' : child.name,
                          ),
                          subtitle: child.children.isNotEmpty
                              ? Text('${child.children.length} подэлементов')
                              : child.stepType == 'stepByStep'
                              ? Text(
                                  '${child.completedSteps}/${child.totalSteps}',
                                )
                              : child.stepType == 'single'
                              ? const Text('Одиночный чекбокс')
                              : const Text('Папка'),
                          trailing: _multiSelect
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _editChild(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _deleteChild(index),
                                    ),
                                  ],
                                ),
                          onTap: () {
                            if (_multiSelect) {
                              setState(() {
                                if (isSelected) {
                                  _selectedIndices.remove(index);
                                } else {
                                  _selectedIndices.add(index);
                                }
                              });
                            } else {
                              _editChild(index);
                            }
                          },
                          onLongPress: () {
                            if (!_multiSelect) {
                              setState(() {
                                _multiSelect = true;
                                _selectedIndices = {index};
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
          if (_multiSelect)
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text('Выбрано: ${_selectedIndices.length}'),
                  const Spacer(),
                  TextButton(
                    onPressed: _cancelSelection,
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _selectedIndices.isEmpty
                        ? null
                        : _deleteSelected,
                    icon: const Icon(Icons.delete),
                    label: const Text('Удалить'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
