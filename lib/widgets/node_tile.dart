import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/app_state.dart';
import '../utils/day_part.dart';
import '../utils/format_minutes.dart';

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
                  context.read<AppState>().historyService.recordUniqueToggle(
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
                title: _buildTitle(
                  TextStyle(
                    fontWeight: hasChildren ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: _buildTrailing(),
                onTap: onTap,
              ),
            ),
          ],
        )
            : ListTile(
          leading: leadingIcon,
          title: _buildTitle(
            TextStyle(
              fontWeight: (isFolder || hasChildren)
                  ? FontWeight.bold
                  : FontWeight.normal,
              decoration: ownCheckbox && node.completed
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
          ),
          subtitle: hasChildren && node.hasOwnProgress
              ? Text(
                  (node.stepType == 'stepByStep'
                          ? 'Шаги: ${node.completedSteps}/${node.totalSteps}'
                          : 'Чекбокс') +
                      _timeSuffix(),
                )
              : null,
          trailing: _buildTrailing(),
          onTap: onTap,
        ),
      ),
    );
  }

  bool get _hasTimeInfo =>
      (node.targetMinutes ?? 0) > 0 || node.loggedMinutes > 0;

  String _durationText() =>
      durationProgressLabel(node.loggedMinutes, node.targetMinutes);

  String _timeSuffix() =>
      _hasTimeInfo ? ' · время ${_durationText()}' : '';

  /// Task name, prefixed with its start time (if any) in a muted colour.
  Widget _buildTitle(TextStyle style) {
    final minutes = node.startMinutes;
    if (minutes == null) return Text(node.name, style: style);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: '${formatMinutes(minutes)}  ',
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.normal,
            ),
          ),
          TextSpan(text: node.name),
        ],
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${node.completedLeaves}/${node.totalLeaves}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (node.hasOwnProgress && _hasTimeInfo)
                  Text(
                    _durationText(),
                    style: TextStyle(
                      fontSize: 10,
                      color: node.timeGoalReached ? Colors.green : Colors.grey,
                    ),
                  ),
              ],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${node.completedSteps}/${node.totalSteps}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (_hasTimeInfo)
              Text(
                _durationText(),
                style: TextStyle(
                  fontSize: 10,
                  color: node.timeGoalReached ? Colors.green : Colors.grey,
                ),
              ),
          ],
        ),
      );
    } else if (_hasTimeInfo) {
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Text(
          _durationText(),
          style: TextStyle(
            fontSize: 12,
            color: node.timeGoalReached ? Colors.green : Colors.grey,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}