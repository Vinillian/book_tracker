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
  late Node _workingCopy; // копия, с которой работаем
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _workingCopy = widget.node.deepCopy();
    _nameController = TextEditingController(text: _workingCopy.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addChild() async {
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

  void _deleteChild(int index) {
    setState(() {
      _workingCopy.children.removeAt(index);
    });
  }

  void _editChild(int index) async {
    final child = _workingCopy.children[index];
    // Передаём копию дочернего узла для редактирования
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
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: 'Название',
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          onChanged: (value) {
            _workingCopy.name = value;
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, _workingCopy);
            },
          ),
        ],
      ),
      body: Column(
        children: [
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
                  onPressed: _addChild,
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
                                    : null),
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
