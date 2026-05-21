import 'package:hive_flutter/hive_flutter.dart';
import '../models/note.dart';

class NoteService {
  final Box<Note> _box;

  NoteService(this._box);

  Box<Note> get box => _box;

  Note? getNoteForDay(String linkedNodeId) {
    try {
      return _box.values.firstWhere((n) => n.linkedNodeId == linkedNodeId);
    } catch (_) {
      return null;
    }
  }

  List<Note> getNotesForNode(String linkedNodeId) {
    return _box.values.where((n) => n.linkedNodeId == linkedNodeId).toList();
  }

  List<Note> get inboxNotes =>
      _box.values.where((n) => n.linkedNodeId == null).toList();

  void createNoteForDay(String linkedNodeId) {
    final note = Note(content: '', linkedNodeId: linkedNodeId);
    _box.put(note.id, note);
  }

  void save(Note note) {
    note.updatedAt = DateTime.now();
    _box.put(note.id, note);
  }

  void delete(String id) {
    // Сначала пробуем удалить по ключу = id (для новых заметок)
    if (_box.containsKey(id)) {
      _box.delete(id);
      return;
    }
    // Если не нашли, ищем заметку, у которой поле id равно переданному id
    dynamic keyToDelete;
    for (var key in _box.keys) {
      final note = _box.get(key);
      if (note != null && note.id == id) {
        keyToDelete = key;
        break;
      }
    }
    if (keyToDelete != null) {
      _box.delete(keyToDelete);
    } else {
      // Если всё равно не нашли, возможно заметка уже удалена
      print('Note with id $id not found for deletion');
    }
  }
}
