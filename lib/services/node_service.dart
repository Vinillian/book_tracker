import 'package:hive_flutter/hive_flutter.dart';
import '../models/node.dart';
import 'note_service.dart';
import 'history_service.dart';
import '../utils/box_keys.dart';
import '../utils/node_copy.dart';
import '../utils/node_ids.dart';
import '../utils/nested_category.dart';
import '../utils/plan_date.dart';

class NodeService {
  final Box<Node> _box;
  final NoteService _noteService;

  /// The ids of every root's tasks as of the last save (#84). A task removed
  /// from a tree is found by comparing with it: the tree itself cannot tell,
  /// because some screens change the stored node in place before saving.
  final Map<dynamic, Set<String>> _knownIds = {};

  NodeService(this._box, this._noteService) {
    for (final key in _box.keys) {
      final node = _box.get(key);
      if (node != null) _knownIds[key] = collectNodeIds(node);
    }
  }

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

  /// The box key of [node], found by its id, or null if it is not stored. A
  /// copy of a stored node (the id is kept by `deepCopy`) finds the same key
  /// (#73).
  dynamic findKey(Node node) => findKeyById<Node>(_box, (n) => n.id, node.id);

  /// Like [findKey], but throws a [StateError] when the node is not stored.
  dynamic getKey(Node node) {
    final key = findKey(node);
    if (key == null) throw StateError('No node with id ${node.id} in the box');
    return key;
  }

  Future<void> add(Node node) async {
    final key = await _box.add(node);
    _knownIds[key] = collectNodeIds(node);
  }

  /// Saves [node] under [key]. History entries of tasks that are no longer in
  /// the tree are removed with them (#84).
  void update(dynamic key, Node node) {
    final now = collectNodeIds(node);
    final before = _knownIds[key];
    if (before != null) {
      final removed = before.difference(now);
      if (removed.isNotEmpty) HistoryService.deleteEntriesForTasks(removed);
    }
    _knownIds[key] = now;
    _box.put(key, node);
  }

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
      _knownIds.remove(key);
      _box.delete(key);
    }
  }

  Node addEmptyDay(DateTime date) {
    final dateStr = _formatDate(date);
    final newDay = Node(
      name: dateStr,
      plannedDate: _dateOnly(date),
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
    final copy = copyAndReset(template);
    copy.name = dateStr;
    copy.plannedDate = _dateOnly(date);
    copy.category = 'planner';
    add(copy);
    _noteService.createNoteForDay(copy.id);
    return copy;
  }

  bool planExistsForDate(DateTime date) => planForDate(date) != null;

  /// The day plan for [date], found by `plannedDate` (legacy name as fallback).
  Node? planForDate(DateTime date) {
    final key = _dateOnly(date);
    for (final plan in plans) {
      if (planDateOf(plan) == key) return plan;
    }
    return null;
  }

  /// One-time lazy migration (#114): fills `plannedDate` for day plans that
  /// only carry their date in the name. Returns how many plans were updated.
  int migratePlannedDates() {
    var updated = 0;
    for (final key in _box.keys.toList()) {
      final node = _box.get(key);
      if (node == null || node.category != 'planner' || node.plannedDate != null) {
        continue;
      }
      // Legacy name first; a day renamed before #114 has no date left in its
      // name, so fall back to the date its History entries were recorded on.
      final date =
          parseLegacyPlanName(node.name) ??
          HistoryService.dominantDateForBook(node.id);
      if (date == null) continue;
      node.plannedDate = _dateOnly(date);
      _box.put(key, node);
      updated++;
    }
    return updated;
  }

  /// One-time lazy migration (#139): resets `category == 'book'` on nested
  /// nodes of books made from templates before the fix in #137. Idempotent, so
  /// it also repairs books that come back through an old backup. Returns how
  /// many nodes were changed.
  int migrateNestedBookCategories() {
    var fixed = 0;
    for (final key in _box.keys.toList()) {
      final node = _box.get(key);
      if (node == null || node.category != 'book') continue;
      final changed = clearNestedBookCategory(node);
      if (changed > 0) {
        _box.put(key, node);
        fixed += changed;
      }
    }
    return fixed;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

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

}