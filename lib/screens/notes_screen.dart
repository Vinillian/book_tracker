import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../models/note.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late Box<Note> notesBox;
  String _searchQuery = '';
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    notesBox = Hive.box<Note>('notes');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _addNote() {
    _showNoteEditor();
  }

  void _editNote(Note note) {
    _showNoteEditor(note: note);
  }

  void _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: Text('Заметка "${note.title}" будет удалена.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await notesBox.delete(note.id);
      setState(() {});
    }
  }

  void _showNoteEditor({Note? note}) {
    _titleController.text = note?.title ?? '';
    _contentController.text = note?.content ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note == null ? 'Новая заметка' : 'Редактировать',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Заголовок',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Содержание',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final title = _titleController.text.trim();
                      final content = _contentController.text.trim();
                      if (title.isEmpty && content.isEmpty) {
                        Navigator.pop(ctx);
                        return;
                      }
                      if (note == null) {
                        final newNote = Note(
                          title: title.isEmpty ? 'Без заголовка' : title,
                          content: content,
                        );
                        notesBox.put(newNote.id, newNote);
                      } else {
                        note.title = title.isEmpty ? 'Без заголовка' : title;
                        note.content = content;
                        note.updatedAt = DateTime.now();
                        notesBox.put(note.id, note);
                      }
                      Navigator.pop(ctx);
                      setState(() {});
                    },
                    child: Text(note == null ? 'Создать' : 'Сохранить'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportNotes() async {
    final notes = notesBox.values.where((n) => n.linkedNodeId == null).toList();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Нет заметок для экспорта')));
      return;
    }

    final jsonList = notes.map((n) => n.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    final bytes = utf8.encode('\uFEFF$jsonString');

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Экспорт заметок',
      fileName: 'notes_${DateTime.now().millisecondsSinceEpoch}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null) {
      await File(result).writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Заметки экспортированы')));
      }
    }
  }

  Future<void> _importNotes() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null) return;

    try {
      final bytes = result.files.first.bytes;
      String jsonString;
      if (bytes != null) {
        jsonString = utf8.decode(bytes);
      } else {
        final path = result.files.first.path;
        if (path == null) throw Exception('Не удалось прочитать файл');
        jsonString = await File(path).readAsString();
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      int imported = 0;
      for (final item in jsonList) {
        final note = Note.fromJson(item);
        if (note.linkedNodeId == null && !notesBox.containsKey(note.id)) {
          await notesBox.put(note.id, note);
          imported++;
        }
      }

      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Импортировано заметок: $imported')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка импорта: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload),
            onPressed: _importNotes,
            tooltip: 'Импорт заметок',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportNotes,
            tooltip: 'Экспорт заметок',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNote,
            tooltip: 'Новая заметка',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchBar(
                  hintText: 'Поиск по заметкам...',
                  leading: const Icon(Icons.search),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Inbox — быстрые заметки без категорий.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: notesBox.listenable(),
              builder: (context, Box<Note> box, _) {
                final notes = box.values
                    .where((n) => n.linkedNodeId == null)
                    .toList();

                if (notes.isEmpty) {
                  return const Center(
                    child: Text('Нет заметок. Нажмите + чтобы создать.'),
                  );
                }

                notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

                final filtered = _searchQuery.isEmpty
                    ? notes
                    : notes.where((note) {
                        final query = _searchQuery.toLowerCase();
                        return note.title.toLowerCase().contains(query) ||
                            note.content.toLowerCase().contains(query);
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('Ничего не найдено'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final note = filtered[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        title: Text(note.title),
                        subtitle: Text(
                          note.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('dd.MM.yy').format(note.updatedAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _editNote(note),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () => _deleteNote(note),
                            ),
                          ],
                        ),
                        onTap: () => _editNote(note),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
