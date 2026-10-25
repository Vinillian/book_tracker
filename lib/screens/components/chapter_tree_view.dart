import 'package:flutter/material.dart';
import '../../models/node.dart';
import '../view_item_screen.dart';
import '../../utils/day_part.dart';
import '../../utils/reorder.dart';
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

  /// Long-press and drag top-level tasks to change their order (#109). With
  /// time grouping only the "Без времени" (no time) group can be dragged: the
  /// other groups are sorted by time, so their order is not stored.
  final bool allowReorder;

  const ChapterTreeView({
    super.key,
    required this.node,
    required this.bookId,
    required this.onNodeUpdated,
    this.planDate,
    this.groupByTime = false,
    this.allowReorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CustomScrollView(slivers: _buildSlivers(context)),
    );
  }

  List<Widget> _buildSlivers(BuildContext context) {
    final children = node.children;
    if (!groupByTime || !children.any((c) => c.startMinutes != null)) {
      return [_buildSection(context, children, reorderable: allowReorder)];
    }
    final groups = <DayPart, List<Node>>{};
    for (final c in children) {
      groups.putIfAbsent(dayPartOf(c.startMinutes), () => []).add(c);
    }
    final slivers = <Widget>[];
    for (final part in DayPart.values) {
      final items = groups[part];
      if (items == null) continue;
      slivers.add(
        SliverToBoxAdapter(child: _buildGroupHeader(context, part, items.length)),
      );
      slivers.add(
        _buildSection(
          context,
          part == DayPart.none ? items : sortedByStartTime(items),
          reorderable: allowReorder && part == DayPart.none,
        ),
      );
    }
    return slivers;
  }

  /// A run of top-level tasks: a plain list, or a list whose items can be
  /// dragged after a long press (a task is dragged together with its visible
  /// subtasks). [items] must be in stored order when [reorderable].
  Widget _buildSection(
    BuildContext context,
    List<Node> items, {
    required bool reorderable,
  }) {
    if (!reorderable) {
      return SliverList(
        delegate: SliverChildListDelegate(_buildChildren(items, 0, context)),
      );
    }
    return SliverReorderableList(
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) {
        node.children = reorderSubset(node.children, items, oldIndex, newIndex);
        onNodeUpdated();
      },
      itemBuilder: (context, index) {
        final child = items[index];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(child.id),
          index: index,
          child: Column(children: _buildChildren([child], 0, context)),
        );
      },
    );
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