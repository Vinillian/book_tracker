import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/node.dart';
import '../models/note.dart';
import '../models/history_entry.dart';
import '../services/node_service.dart';
import '../services/note_service.dart';
import '../services/history_service.dart';

class AppState extends ChangeNotifier {
  late final NodeService _nodeService;
  late final NoteService _noteService;
  late final Box<HistoryEntry> _historyBox;

  AppState({
    required Box<Node> templatesBox,
    required Box<Note> notesBox,
    required Box<HistoryEntry> historyBox,
  }) {
    _historyBox = historyBox;
    // Инициализируем HistoryService кастомным боксом (для тестов в будущем)
    HistoryService.init(historyBox);
    _noteService = NoteService(notesBox);
    _nodeService = NodeService(templatesBox, _noteService);
  }

  // ---------- Геттеры для боксов (для прослушки через provider) ----------
  Box<Node> get templatesBox => _nodeService.box;
  Box<Note> get notesBox => _noteService.box;
  Box<HistoryEntry> get historyBox => _historyBox;

  // ---------- Прокси к NodeService ----------
  List<Node> get books => _nodeService.books;
  List<Node> get plans => _nodeService.plans;
  List<Node> get templates => _nodeService.templates;

  void addNode(Node node) {
    _nodeService.add(node);
    notifyListeners();
  }

  void updateNode(dynamic key, Node node) {
    _nodeService.update(key, node);
    notifyListeners();
  }

  void deleteNode(dynamic key) {
    _nodeService.delete(key);
    notifyListeners();
  }

  Node addEmptyDay(DateTime date) {
    final day = _nodeService.addEmptyDay(date);
    notifyListeners();
    return day;
  }

  Node addDayFromTemplate(Node template, DateTime date) {
    final day = _nodeService.addDayFromTemplate(template, date);
    notifyListeners();
    return day;
  }

  bool planExistsForDate(DateTime date) => _nodeService.planExistsForDate(date);

  Node? getNodeById(String id) => _nodeService.getById(id);
  dynamic getKeyForNode(Node node) => _nodeService.getKey(node);

  // ---------- Прокси к NoteService ----------
  Note? getNoteForDay(String linkedNodeId) => _noteService.getNoteForDay(linkedNodeId);
  void createNoteForDay(String linkedNodeId) {
    _noteService.createNoteForDay(linkedNodeId);
    notifyListeners();
  }
  void saveNote(Note note) {
    _noteService.save(note);
    notifyListeners();
  }
  void deleteNote(String id) {
    _noteService.delete(id);
    notifyListeners();
  }

  List<Note> get inboxNotes => _noteService.inboxNotes;

  // ---------- Уведомление об изменении бокса извне (на случай прямых изменений Hive) ----------
  void notify() => notifyListeners();
}