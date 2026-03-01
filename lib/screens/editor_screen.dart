import 'package:flutter/material.dart';
import '../models/node.dart';

class EditorScreen extends StatefulWidget {
  final Node node;

  const EditorScreen({super.key, required this.node});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Node _node;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _node = widget.node;
    _nameController = TextEditingController(text: _node.name);
  }

  void _addChild() {
    setState(() {
      _node.children.add(Node.leaf('Новый элемент'));
    });
  }

  void _deleteChild(int index) {
    setState(() {
      _node.children.removeAt(index);
    });
  }

  void _editChild(int index) async {
    final child = _node.children[index];
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(node: child),
      ),
    );
    if (updated != null) {
      setState(() {
        _node.children[index] = updated;
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
            _node.name = value;
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, _node);
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
                  child: Text(
                    'Всего листьев: ${_node.totalLeaves}',
                    style: const TextStyle(fontSize: 16),
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
            child: ReorderableListView.builder(
              itemCount: _node.children.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _node.children.removeAt(oldIndex);
                  _node.children.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final child = _node.children[index];
                return Card(
                  key: ValueKey(child),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text(child.name),
                    subtitle: child.children.isNotEmpty
                        ? Text('${child.children.length} подэлементов')
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (child.children.isNotEmpty)
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