import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/app_state.dart';
import '../services/history_service.dart';
import '../utils/day_dialogs.dart';
import '../utils/plan_date.dart';
import 'components/progress_card.dart';
import 'components/day_note_card.dart';
import 'components/day_done_section.dart';
import 'components/chapter_tree_view.dart';
import 'template_manager_screen.dart';
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

  /// Adds the tasks of a chosen template to this day (#117).
  Future<void> _addFromTemplate() async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final template = await Navigator.push<Node>(
      context,
      MaterialPageRoute(
        builder: (_) => const TemplateManagerScreen(
          selectionMode: true,
          filterCategory: 'planner',
        ),
      ),
    );
    if (template == null || !mounted) return;
    final count = appState.appendTasksToDay(_node, template);
    setState(() {});
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'В шаблоне "${template.name}" нет задач'
              : 'Добавлено задач: $count из шаблона "${template.name}"',
        ),
      ),
    );
  }

  /// Copies this day to another date (completion is reset). If a day already
  /// exists there, offers to add the tasks to it (#117).
  Future<void> _copyDay() async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final current = _planDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current.add(const Duration(days: 1)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Копировать в день',
    );
    if (picked == null || !mounted) return;
    final date = DateTime(picked.year, picked.month, picked.day);
    if (date == _planDate) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Выберите другой день')),
      );
      return;
    }
    final dateStr = DateFormat('dd.MM.yyyy').format(date);
    final existing = appState.planForDate(date);
    final Node target;
    final String message;
    if (existing == null) {
      target = appState.addDayFromTemplate(_node, date);
      message = 'День "$dateStr" создан копированием';
    } else {
      final add = await confirmAppendToExistingDay(context, dateStr);
      if (!add || !mounted) return;
      final count = appState.appendTasksToDay(existing, _node);
      target = existing;
      message = count == 0
          ? 'В этом дне нет задач для копирования'
          : 'Добавлено задач: $count в день "$dateStr"';
    }
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        // With an action, SnackBar defaults to persist = true and never closes.
        persist: false,
        action: SnackBarAction(
          label: 'Открыть',
          onPressed: () => _openDay(appState, target),
        ),
      ),
    );
  }

  void _openDay(AppState appState, Node day) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookScreen(
          node: day,
          onNodeUpdated: () =>
              appState.updateNode(appState.getKeyForNode(day), day),
        ),
      ),
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
            : (_node.category == 'planner'
                  ? [
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'template') _addFromTemplate();
                          if (value == 'copy') _copyDay();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'template',
                            child: Text('Добавить из шаблона…'),
                          ),
                          PopupMenuItem(
                            value: 'copy',
                            child: Text('Копировать день…'),
                          ),
                        ],
                      ),
                    ]
                  : null),
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
            allowReorder: _node.category == 'planner',
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
