import 'package:flutter/material.dart';
import '../../models/node.dart';
import '../view_item_screen.dart';
import '../../widgets/node_tile.dart';

class ChapterTreeView extends StatelessWidget {
  final Node node;
  final String bookId;
  final VoidCallback onNodeUpdated;

  const ChapterTreeView({
    super.key,
    required this.node,
    required this.bookId,
    required this.onNodeUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView(children: _buildChildren(node, 0, context)),
    );
  }

  List<Widget> _buildChildren(Node node, int depth, BuildContext context) {
    List<Widget> widgets = [];
    for (var child in node.children) {
      widgets.add(
        NodeTile(
          node: child,
          depth: depth,
          bookId: bookId,
          onCheckboxChanged: () {
            child.toggle();
            onNodeUpdated();
          },
          onTap: () => _openViewScreen(context, child),
          onExpandToggle: child.children.isNotEmpty
              ? () {
                  // Тоггл через callback родителя, если нужно
                  child.isExpanded = !child.isExpanded;
                  onNodeUpdated();
                }
              : null,
        ),
      );
      if (child.isExpanded && child.children.isNotEmpty) {
        widgets.addAll(_buildChildren(child, depth + 1, context));
      }
    }
    return widgets;
  }

  void _openViewScreen(BuildContext context, Node node) async {
    if (node.children.isNotEmpty) {
      node.isExpanded = !node.isExpanded;
      onNodeUpdated();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewItemScreen(
          bookId: bookId,
          node: node,
          onNodeUpdated: onNodeUpdated,
        ),
      ),
    );
  }
}
