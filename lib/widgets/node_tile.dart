import 'package:flutter/material.dart';
import '../models/node.dart';
import '../services/history_service.dart';

class NodeTile extends StatelessWidget {
  final Node node;
  final int depth;
  final String bookId;
  final VoidCallback? onCheckboxChanged;
  final VoidCallback onTap;
  final VoidCallback? onExpandToggle;
  final DateTime? planDate;

  const NodeTile({
    super.key,
    required this.node,
    required this.depth,
    required this.bookId,
    this.onCheckboxChanged,
    required this.onTap,
    this.onExpandToggle,
    this.planDate,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasChildren = node.children.isNotEmpty;
    final bool isLeaf = !hasChildren && node.stepType != 'folder';
    // Pure container: a folder, or a node with children and no own progress.
    final bool isFolder =
        node.stepType == 'folder' || (hasChildren && !node.hasOwnProgress);
    final bool isSingle = node.stepType == 'single';
    // Checkbox row: a single-type leaf, or a parent that keeps its own checkbox.
    final bool ownCheckbox = isSingle && (isLeaf || node.hasOwnProgress);

    Widget leadingIcon;
    if (isFolder) {
      leadingIcon = node.isExpanded
          ? const Icon(Icons.folder_open)
          : const Icon(Icons.folder);
    } else {
      if (isSingle) {
        leadingIcon = node.completed
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.radio_button_unchecked, color: Colors.grey);
      } else {
        leadingIcon = const Icon(Icons.list, color: Colors.blue);
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Padding(
        padding: EdgeInsets.only(left: depth * 16.0),
        child: ownCheckbox
            ? Row(
          children: [
            Checkbox(
              value: node.completed,
              onChanged: (_) {
                onCheckboxChanged?.call();
                if (!node.excludeFromHistory) {
                  HistoryService.recordUniqueToggle(
                    bookId: bookId,
                    node: node,
                    newValue: node.completed,
                    targetDate: planDate,
                  );
                }
              },
            ),
            Expanded(
              child: ListTile(
                title: Text(
                  node.name,
                  style: TextStyle(
                    fontWeight: hasChildren ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: hasChildren ? _buildTrailing() : null,
                onTap: onTap,
              ),
            ),
          ],
        )
            : ListTile(
          leading: leadingIcon,
          title: Text(
            node.name,
            style: TextStyle(
              fontWeight: (isFolder || hasChildren)
                  ? FontWeight.bold
                  : FontWeight.normal,
              decoration: ownCheckbox && node.completed
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
          ),
          subtitle: hasChildren && node.stepType == 'stepByStep'
              ? Text('Шаги: ${node.completedSteps}/${node.totalSteps}')
              : null,
          trailing: _buildTrailing(),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildTrailing() {
    if (node.children.isNotEmpty || node.stepType == 'folder') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          IconButton(
            icon: Icon(node.isExpanded ? Icons.expand_less : Icons.expand_more),
            onPressed: onExpandToggle,
          ),
        ],
      );
    } else if (node.stepType == 'stepByStep') {
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Text(
          '${node.completedSteps}/${node.totalSteps}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}