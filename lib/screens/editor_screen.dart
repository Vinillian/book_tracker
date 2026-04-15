import 'package:flutter/material.dart';
import '../models/node.dart';
import 'item_card_screen.dart';

class EditorScreen extends StatefulWidget {
  final Node node; // исходный узел (будет скопирован)

  const EditorScreen({super.key, required this.node});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Node _workingCopy;
  late TextEditingController _nameController;
  String? _category;

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
    super.dispose();
  }

  void _showAddChildDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить элемент'),
        content: const Text('Выберите тип нового элемента:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addLeaf();
            },
            child: const Text('Лист'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addFolder();
            },
            child: const Text('Папка'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  void _addLeaf() async {
    final newNode = Node.leaf('Новый элемент');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemCardScreen(node: newNode, isNew: true),
      ),
    );
    if (result != null && result is Node) {
      setState(() {
        _workingCopy.children.add(result);
      });
    }
  }

  void _addFolder() {
    final newNode = Node(name: 'Новая папка', children: [], stepType: 'folder');
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
        builder: (context) =>
            ItemCardScreen(node: child.deepCopy(), isNew: false),
      ),
    );
    if (result != null && result is Node) {
      setState(() {
        _workingCopy.children[index] = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isRoot = widget.node.category != null; // Корень имеет категорию

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
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
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
                value: _category,
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
                        'Всего единиц: ${_workingCopy.totalLeaves}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddChildDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _workingCopy.children.isEmpty
                ? const Center(
                    child: Text(
                      'Нет дочерних элементов. Нажмите "Добавить", чтобы создать.',
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: _workingCopy.children.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _workingCopy.children.removeAt(oldIndex);
                        _workingCopy.children.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final child = _workingCopy.children[index];
                      return Card(
                        key: ValueKey(child),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle),
                          ),
                          title: Text(child.name),
                          subtitle: child.children.isNotEmpty
                              ? Text('${child.children.length} подэлементов')
                              : (child.stepType == 'stepByStep'
                                    ? Text(
                                        '${child.completedSteps}/${child.totalSteps}',
                                      )
                                    : child.stepType == 'single'
                                    ? const Text('Одиночный чекбокс')
                                    : const Text('Папка')),
                          trailing: Row(
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
                          onTap: () => _editChild(index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
