import 'package:flutter/material.dart';
import '../models/node.dart';
import 'editor_screen.dart';

class BookScreen extends StatefulWidget {
  final Node node;
  final VoidCallback onNodeUpdated;

  const BookScreen({
    super.key,
    required this.node,
    required this.onNodeUpdated,
  });

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  late Node _node;

  @override
  void initState() {
    super.initState();
    _node = widget.node;
  }

  void _toggleExpanded(Node node) {
    setState(() {
      node.isExpanded = !node.isExpanded;
    });
  }

  void _toggleCompleted(Node node) {
    if (node.children.isNotEmpty) return;
    setState(() {
      node.completed = !node.completed;
    });
    widget.onNodeUpdated();
  }

  // Открыть редактор для указанного узла
  Future<void> _openEditor(Node targetNode) async {
    final updatedNode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditorScreen(node: targetNode)),
    );
    if (updatedNode != null) {
      // Если редактировали корневой узел книги
      if (targetNode == _node) {
        _node.name = updatedNode.name;
        _node.children = updatedNode.children;
      } else {
        // Если редактировали внутренний узел, нужно найти его и обновить
        _updateNodeInTree(_node, targetNode, updatedNode);
      }
      widget.onNodeUpdated();
      setState(() {});
    }
  }

  // Рекурсивно обновить узел в дереве
  bool _updateNodeInTree(Node currentNode, Node oldNode, Node newNode) {
    if (currentNode == oldNode) {
      currentNode.name = newNode.name;
      currentNode.children = newNode.children;
      return true;
    }
    for (int i = 0; i < currentNode.children.length; i++) {
      if (_updateNodeInTree(currentNode.children[i], oldNode, newNode)) {
        return true;
      }
    }
    return false;
  }

  Widget _buildNodeTile(Node node, int depth) {
    final bool isLeaf = node.children.isEmpty;
    final icon = isLeaf
        ? (node.completed
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.radio_button_unchecked, color: Colors.grey))
        : (node.isExpanded
              ? const Icon(Icons.folder_open)
              : const Icon(Icons.folder));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: InkWell(
        onTap: isLeaf
            ? () => _toggleCompleted(node)
            : () => _toggleExpanded(node),
        onLongPress: isLeaf
            ? null
            : () => _openEditor(node), // долгое нажатие на папку
        child: Padding(
          padding: EdgeInsets.only(left: depth * 16.0),
          child: ListTile(
            leading: icon,
            title: Text(
              node.name,
              style: TextStyle(
                fontWeight: isLeaf ? FontWeight.normal : FontWeight.bold,
                decoration: isLeaf && node.completed
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isLeaf) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      '${node.completedLeaves}/${node.totalLeaves}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      value: node.totalLeaves > 0
                          ? node.completedLeaves / node.totalLeaves
                          : 0,
                      strokeWidth: 2,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        node.completedLeaves == node.totalLeaves
                            ? Colors.green
                            : Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(node.isExpanded ? Icons.expand_less : Icons.expand_more),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChildren(Node node, int depth) {
    final List<Widget> widgets = [];
    for (int i = 0; i < node.children.length; i++) {
      final child = node.children[i];
      widgets.add(_buildNodeTile(child, depth));
      if (child.isExpanded && child.children.isNotEmpty) {
        widgets.addAll(_buildChildren(child, depth + 1));
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_node.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _openEditor(_node), // редактировать всю книгу
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Прогресс',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_node.completedLeaves}/${_node.totalLeaves}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _node.totalLeaves > 0
                        ? _node.completedLeaves / _node.totalLeaves
                        : 0,
                    backgroundColor: Colors.grey[200],
                    color: Colors.blue,
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: ListView(children: _buildChildren(_node, 0))),
        ],
      ),
    );
  }
}
