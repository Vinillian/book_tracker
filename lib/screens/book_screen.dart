import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/app_state.dart';
import '../services/history_service.dart';
import '../utils/plan_date.dart';
import 'components/progress_card.dart';
import 'components/day_note_card.dart';
import 'components/day_done_section.dart';
import 'components/chapter_tree_view.dart';
import 'components/quick_add_bar.dart';
import 'components/standard_task_quick_picker.dart';

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
  late TextEditingController _nameController;
  bool _isEditingTitle = false;
  DateTime? _planDate;

  @override
  void initState() {
    super.initState();
    _node = widget.node;
    _nameController = TextEditingController(text: _node.name);
    // The date comes from plannedDate, not from the title (#114).
    _planDate = _node.category == 'planner' ? planDateOf(_node) : null;
  }

  void _saveTitle() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != _node.name) {
      setState(() => _node.name = newName);
      widget.onNodeUpdated();
      context.read<AppState>().notify();
    }
    setState(() => _isEditingTitle = false);
  }

  /// Quick add (#109): works on the live node and saves through
  /// `onNodeUpdated`, like ticking a task does.
  void _addTask(Node task) {
    setState(() => _node.children.add(task));
    widget.onNodeUpdated();
  }

  Future<void> _openStandardTaskPicker() {
    return showStandardTaskQuickPicker(
      context,
      onPick: (task) => _addTask(task.toNode()),
    );
  }

  Widget _buildTitle() {
    final date = _planDate;
    if (date == null) return Text(_node.name);
    final dateStr = DateFormat('dd.MM.yyyy').format(date);
    if (dateStr == _node.name) return Text(_node.name);
    // Renamed day: keep its date visible under the free title.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_node.name),
        Text(
          dateStr,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isEditingTitle
            ? TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Название',
                  border: InputBorder.none,
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                onSubmitted: (_) => _saveTitle(),
              )
            : GestureDetector(
                onTap: () => setState(() => _isEditingTitle = true),
                child: _buildTitle(),
              ),
        actions: _isEditingTitle
            ? [
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _saveTitle,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isEditingTitle = false;
                      _nameController.text = _node.name;
                    });
                  },
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          // With the keyboard open (quick add) the cards above the list may not
          // fit: cap their height and let them scroll instead of overflowing.
          // The widget tree is the same either way, so nothing loses its state.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.viewInsetsOf(context).bottom > 0
                  ? MediaQuery.sizeOf(context).height * 0.3
                  : double.infinity,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ProgressCard(node: _node),
                  DayNoteCard(node: _node),
                  if (_planDate != null)
                    DayDoneSection(
                      entries: HistoryService.getEntriesForDay(_planDate!),
                    ),
                ],
              ),
            ),
          ),
          ChapterTreeView(
            node: _node,
            bookId: _node.id,
            onNodeUpdated: () {
              widget.onNodeUpdated();
              setState(() {});
            },
            planDate: _planDate,
            groupByTime: _node.category == 'planner',
          ),
          if (_node.category == 'planner')
            QuickAddBar(
              onAdd: (name) => _addTask(Node.leaf(name)),
              onOpenPicker: _openStandardTaskPicker,
            ),
        ],
      ),
    );
  }
}
