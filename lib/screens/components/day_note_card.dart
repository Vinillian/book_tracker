import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/node.dart';
import '../../models/note.dart';
import '../../providers/app_state.dart';

class DayNoteCard extends StatefulWidget {
  final Node node;

  const DayNoteCard({super.key, required this.node});

  @override
  State<DayNoteCard> createState() => _DayNoteCardState();
}

class _DayNoteCardState extends State<DayNoteCard> {
  Note? _dayNote;
  final TextEditingController _noteController = TextEditingController();
  bool _isEditingNote = false;

  @override
  void initState() {
    super.initState();
    _loadDayNote();
  }

  void _loadDayNote() {
    final appState = context.read<AppState>();
    _dayNote = appState.getNoteForDay(widget.node.id);
    if (_dayNote == null) {
      appState.createNoteForDay(widget.node.id);
      _dayNote = appState.getNoteForDay(widget.node.id);
    }
    _noteController.text = _dayNote?.content ?? '';
  }

  void _saveDayNote() {
    if (_dayNote == null) return;
    final newContent = _noteController.text.trim();
    if (newContent != _dayNote!.content) {
      _dayNote!.content = newContent;
      context.read<AppState>().saveNote(_dayNote!);
    }
    setState(() => _isEditingNote = false);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.node.category != 'planner') return const SizedBox.shrink();

    return Card(
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(
                    _isEditingNote ? Icons.check : Icons.edit,
                    size: 20,
                  ),
                  onPressed: () {
                    if (_isEditingNote) {
                      _saveDayNote();
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
                  color: _dayNote?.content.isEmpty == true ? Colors.grey : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
