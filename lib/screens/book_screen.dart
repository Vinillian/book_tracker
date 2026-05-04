import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/app_state.dart';
import 'components/progress_card.dart';
import 'components/day_note_card.dart';
import 'components/chapter_tree_view.dart';

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

  @override
  void initState() {
    super.initState();
    _node = widget.node;
    _nameController = TextEditingController(text: _node.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveTitle() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != _node.name) {
      setState(() => _node.name = newName);
      widget.onNodeUpdated();
      // Уведомляем провайдер, что данные изменились (если нужно)
      context.read<AppState>().notify();
    }
    setState(() => _isEditingTitle = false);
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
          ProgressCard(node: _node),
          DayNoteCard(node: _node),
          ChapterTreeView(
            node: _node,
            bookId: _node.id,
            onNodeUpdated: () {
              widget.onNodeUpdated();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}
