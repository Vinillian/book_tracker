import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/node.dart';
import '../models/note.dart';
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
  late TextEditingController _nameController;
  bool _isEditingTitle = false;

  // Дневная заметка
  Note? _dayNote;
  final TextEditingController _noteController = TextEditingController();
  bool _isEditingNote = false;

  @override
  void initState() {
    super.initState();
    _node = widget.node;
    _nameController = TextEditingController(text: _node.name);
    _loadDayNote();
  }

  void _loadDayNote() {
    if (_node.category == 'planner') {
      final notesBox = Hive.box<Note>('notes');
      _dayNote = notesBox.values.firstWhere(
        (n) => n.linkedNodeId == _node.id,
        orElse: () => Note(content: ''),
      );
      if (_dayNote!.id.isNotEmpty) {
        _noteController.text = _dayNote!.content;
      }
    }
  }

  /// Только сохраняет данные заметки, без setState
  void _saveDayNote() {
    if (_dayNote == null) return;
    final newContent = _noteController.text.trim();
    if (newContent != _dayNote!.content) {
      _dayNote!.content = newContent;
      _dayNote!.updatedAt = DateTime.now();
      final notesBox = Hive.box<Note>('notes');
      notesBox.put(_dayNote!.id, _dayNote!);
    }
  }

  @override
  void dispose() {
    _saveDayNote(); // автосохранение заметки при закрытии экрана
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
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
          bookId: _node.id,
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
          bookId: _node.id,
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

  void _saveTitle() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != _node.name) {
      setState(() => _node.name = newName);
      widget.onNodeUpdated();
    }
    setState(() => _isEditingTitle = false);
  }

  void _startEditingTitle() {
    setState(() => _isEditingTitle = true);
  }

  @override
  Widget build(BuildContext context) {
    final bool isPlanner = _node.category == 'planner';

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
                onTap: _startEditingTitle,
                child: Text(_node.name),
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
          if (isPlanner) ...[
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Заметка дня',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isEditingNote ? Icons.check : Icons.edit,
                            size: 20,
                          ),
                          onPressed: () {
                            if (_isEditingNote) {
                              _saveDayNote();
                              setState(() => _isEditingNote = false);
                            } else {
                              setState(() => _isEditingNote = true);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isEditingNote)
                      TextField(
                        controller: _noteController,
                        maxLines: 5,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Введите заметку...',
                          border: OutlineInputBorder(),
                        ),
                      )
                    else
                      Text(
                        _dayNote?.content.isEmpty == true
                            ? 'Нет заметки'
                            : _dayNote!.content,
                        style: TextStyle(
                          color: _dayNote?.content.isEmpty == true
                              ? Colors.grey
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          Expanded(child: ListView(children: _buildChildren(_node, 0))),
        ],
      ),
    );
  }
}
