import 'package:flutter/material.dart';
import '../../models/node.dart';
import '../view_item_screen.dart';
import '../../widgets/node_tile.dart';

class ChapterTreeView extends StatelessWidget {
  final Node node;
  final String bookId;
  final VoidCallback onNodeUpdated;
  final DateTime? planDate;

  const ChapterTreeView({
    super.key,
    required this.node,
    required this.bookId,
    required this.onNodeUpdated,
    this.planDate,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView(children: _buildChildren(node.children, 0, context)),
    );
  }

  List<Widget> _buildChildren(
      List<Node> children,
      int depth,
      BuildContext context,
      ) {
    List<Widget> widgets = [];
    for (var child in children) {
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
            child.isExpanded = !child.isExpanded;
            onNodeUpdated();
          }
              : null,
          planDate: planDate,
        ),
      );
      if (child.isExpanded && child.children.isNotEmpty) {
        widgets.addAll(_buildChildren(child.children, depth + 1, context));
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
          targetDate: planDate,
        ),
      ),
    );
  }
}