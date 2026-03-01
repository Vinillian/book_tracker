import 'package:flutter/material.dart';
import '../models/node.dart';

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

  Widget _buildNodeTile(Node node) {
    final bool isLeaf = node.children.isEmpty;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: isLeaf
          ? CheckboxListTile(
              title: Text(node.name),
              value: node.completed,
              onChanged: (value) => _toggleCompleted(node),
              secondary: const Icon(Icons.task),
            )
          : ListTile(
              title: Text(node.name),
              subtitle: Text('${node.completedLeaves}/${node.totalLeaves}'),
              trailing: IconButton(
                icon: Icon(
                  node.isExpanded ? Icons.expand_less : Icons.expand_more,
                ),
                onPressed: () => _toggleExpanded(node),
              ),
              onTap: () => _toggleExpanded(node),
            ),
    );
  }

  List<Widget> _buildChildren(Node node) {
    final List<Widget> widgets = [];
    for (int i = 0; i < node.children.length; i++) {
      final child = node.children[i];
      widgets.add(_buildNodeTile(child));
      if (child.isExpanded && child.children.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Column(children: _buildChildren(child)),
          ),
        );
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_node.name)),
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
          Expanded(child: ListView(children: _buildChildren(_node))),
        ],
      ),
    );
  }
}
