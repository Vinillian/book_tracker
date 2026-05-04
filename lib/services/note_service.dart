import 'package:hive_flutter/hive_flutter.dart';
import '../models/note.dart';

class NoteService {
  final Box<Note> _box;

  NoteService(this._box);

  // ---------- Публичный доступ к боксу ----------
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
    _box.delete(id);
  }
}
