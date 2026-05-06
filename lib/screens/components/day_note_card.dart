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
  bool _expanded = false;

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
    if (_isEditingNote) {
      _saveDayNote();
    }
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.node.category != 'planner') return const SizedBox.shrink();

    final noteContent = _dayNote?.content ?? '';
    final bool isEmpty = noteContent.isEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок и кнопки
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Заметка дня',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Кнопка разворачивания/сворачивания в режиме просмотра
                    if (!_isEditingNote && !isEmpty)
                      IconButton(
                        icon: Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _expanded = !_expanded),
                        tooltip: _expanded ? 'Свернуть' : 'Развернуть',
                      ),
                    // Кнопка редактирования
                    IconButton(
                      icon: Icon(
                        _isEditingNote ? Icons.check : Icons.edit,
                        size: 20,
                      ),
                      onPressed: () {
                        if (_isEditingNote) {
                          _saveDayNote();
                        } else {
                          setState(() {
                            _isEditingNote = true;
                            _expanded = false;
                          });
                        }
                      },
                      tooltip: _isEditingNote ? 'Сохранить' : 'Редактировать',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Основное содержимое
            if (_isEditingNote)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: TextField(
                    controller: _noteController,
                    maxLines: null,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Введите заметку...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              )
            else
              isEmpty
                  ? const Text(
                      'Нет заметки',
                      style: TextStyle(color: Colors.grey),
                    )
                  : _expanded
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(child: Text(noteContent)),
                    )
                  : GestureDetector(
                      onTap: () => setState(() => _expanded = true),
                      child: Text(
                        noteContent,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
          ],
        ),
      ),
    );
  }
}
