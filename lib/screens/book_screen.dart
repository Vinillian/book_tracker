import 'package:flutter/material.dart';
import '../models/node.dart';
import '../widgets/node_tile.dart';
import 'view_item_screen.dart';

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

  void _toggleExpanded(Node node) =>
      setState(() => node.isExpanded = !node.isExpanded);

  void _openViewScreen(Node node) async {
    if (node.children.isNotEmpty) {
      _toggleExpanded(node);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewItemScreen(
          node: node,
          onNodeUpdated: () {
            widget.onNodeUpdated();
            setState(() {});
          },
        ),
      ),
    );
  }

  List<Widget> _buildChildren(Node node, int depth) {
    List<Widget> widgets = [];
    for (var child in node.children) {
      widgets.add(
        NodeTile(
          node: child,
          depth: depth,
          onCheckboxChanged: () {
            child.toggle();
            widget.onNodeUpdated();
            setState(() {});
          },
          onTap: () => _openViewScreen(child),
          onExpandToggle: child.children.isNotEmpty
              ? () => _toggleExpanded(child)
              : null,
        ),
      );
      if (child.isExpanded && child.children.isNotEmpty) {
        widgets.addAll(_buildChildren(child, depth + 1));
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
          Expanded(child: ListView(children: _buildChildren(_node, 0))),
        ],
      ),
    );
  }
}
