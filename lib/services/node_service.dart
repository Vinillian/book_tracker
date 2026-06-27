import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/node.dart';
import 'note_service.dart';
import 'history_service.dart';

class NodeService {
  final Box<Node> _box;
  final NoteService _noteService;

  NodeService(this._box, this._noteService);

  Box<Node> get box => _box;

  List<Node> get books => _box.values.where((n) => n.category == 'book').toList();
  List<Node> get plans => _box.values.where((n) => n.category == 'planner').toList();
  List<Node> get templates => _box.values.where((n) => n.category == 'template').toList();

  Node? getById(String id) {
    try {
      return _box.values.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  dynamic getKey(Node node) {
    return _box.keys.firstWhere((k) => _box.get(k) == node);
  }

  void add(Node node) => _box.add(node);
  void update(dynamic key, Node node) => _box.put(key, node);

  void delete(dynamic key) {
    final node = _box.get(key);
    if (node != null) {
      // Удаляем заметки
      final notes = _noteService.getNotesForNode(node.id);
      for (final note in notes) {
        _noteService.delete(note.id);
      }

      // Удаляем историю для этой книги/плана
      HistoryService.deleteEntriesForNode(node.id);

      // Удаляем сам узел
      _box.delete(key);
    }
  }

  Node addEmptyDay(DateTime date) {
    final dateStr = _formatDate(date);
    final newDay = Node(
      name: dateStr,
      children: [],
      category: 'planner',
      stepType: 'folder',
    );
    add(newDay);
    _noteService.createNoteForDay(newDay.id);
    return newDay;
  }

  Node addDayFromTemplate(Node template, DateTime date) {
    final dateStr = _formatDate(date);
    final copy = _copyAndReset(template);
    copy.name = dateStr;
    copy.category = 'planner';
    add(copy);
    _noteService.createNoteForDay(copy.id);
    return copy;
  }

  bool planExistsForDate(DateTime date) {
    final dateStr = _formatDate(date);
    return plans.any((n) => n.name == dateStr);
  }

  Node? getPlanByName(String name) {
    try {
      return plans.firstWhere((n) => n.name == name);
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}'
        '.${date.month.toString().padLeft(2, '0')}'
        '.${date.year}';
  }

  Node _copyAndReset(Node node) {
    final copy = node.deepCopy();
    copy.id = const Uuid().v4();
    if (copy.children.isEmpty) {
      copy.completed = false;
      copy.completedSteps = 0;
    } else {
      copy.children = copy.children.map((c) => _copyAndReset(c)).toList();
    }
    return copy;
  }
}