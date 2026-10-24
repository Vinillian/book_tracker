import 'package:flutter/material.dart';
import '../../models/node.dart';
import '../view_item_screen.dart';
import '../../utils/day_part.dart';
import '../../widgets/node_tile.dart';

class ChapterTreeView extends StatelessWidget {
  final Node node;
  final String bookId;
  final VoidCallback onNodeUpdated;
  final DateTime? planDate;

  /// Group the top level by time of day (morning / day / evening / no time)
  /// when at least one task has a start time. Display only: the stored order
  /// of the tasks is not changed (#116).
  final bool groupByTime;

  const ChapterTreeView({
    super.key,
    required this.node,
    required this.bookId,
    required this.onNodeUpdated,
    this.planDate,
    this.groupByTime = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView(children: _buildTopLevel(context)),
    );
  }

  List<Widget> _buildTopLevel(BuildContext context) {
    final children = node.children;
    if (!groupByTime || !children.any((c) => c.startMinutes != null)) {
      return _buildChildren(children, 0, context);
    }
    final groups = <DayPart, List<Node>>{};
    for (final c in children) {
      groups.putIfAbsent(dayPartOf(c.startMinutes), () => []).add(c);
    }
    final widgets = <Widget>[];
    for (final part in DayPart.values) {
      final items = groups[part];
      if (items == null) continue;
      widgets.add(_buildGroupHeader(context, part, items.length));
      widgets.addAll(
        _buildChildren(
          part == DayPart.none ? items : sortedByStartTime(items),
          0,
          context,
        ),
      );
    }
    return widgets;
  }

  Widget _buildGroupHeader(BuildContext context, DayPart part, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        '${dayPartLabel(part)} · $count',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
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
    // A pure container expands on tap; a task with its own progress opens its
    // card (expand/collapse is the chevron).
    if (node.children.isNotEmpty && !node.hasOwnProgress) {
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