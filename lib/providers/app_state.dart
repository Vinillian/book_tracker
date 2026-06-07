import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/node.dart';
import '../models/note.dart';
import '../models/history_entry.dart';
import '../models/standard_task.dart';
import '../models/tracked_activity.dart';

import '../services/node_service.dart';
import '../services/note_service.dart';
import '../services/history_service.dart';

class AppState extends ChangeNotifier {
  late final NodeService _nodeService;
  late final NoteService _noteService;

  late final Box<HistoryEntry> _historyBox;
  late final Box<StandardTask> _standardTasksBox;
  late final Box<TrackedActivity> _trackedActivitiesBox;

  AppState({
    required Box<Node> templatesBox,
    required Box<Note> notesBox,
    required Box<HistoryEntry> historyBox,
    required Box<StandardTask> standardTasksBox,
    required Box<TrackedActivity> trackedActivitiesBox,
  }) {
    _historyBox = historyBox;
    _standardTasksBox = standardTasksBox;
    _trackedActivitiesBox = trackedActivitiesBox;

    HistoryService.init(historyBox);

    _noteService = NoteService(notesBox);
    _nodeService = NodeService(
      templatesBox,
      _noteService,
    );

    // Обновляем UI при изменении истории
    _historyBox.watch().listen((_) {
      notifyListeners();
    });

    // Обновляем UI при изменении отслеживаемых задач
    _trackedActivitiesBox.watch().listen((_) {
      notifyListeners();
    });
  }

  // ---------- Геттеры для боксов ----------

  Box<Node> get templatesBox => _nodeService.box;

  Box<Note> get notesBox => _noteService.box;

  Box<HistoryEntry> get historyBox => _historyBox;

  Box<StandardTask> get standardTasksBox =>
      _standardTasksBox;

  Box<TrackedActivity> get trackedActivitiesBox =>
      _trackedActivitiesBox;

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

  Node addDayFromTemplate(
      Node template,
      DateTime date,
      ) {
    final day = _nodeService.addDayFromTemplate(
      template,
      date,
    );

    notifyListeners();

    return day;
  }

  bool planExistsForDate(DateTime date) =>
      _nodeService.planExistsForDate(date);

  Node? getNodeById(String id) =>
      _nodeService.getById(id);

  dynamic getKeyForNode(Node node) =>
      _nodeService.getKey(node);

  // ---------- Прокси к NoteService ----------

  Note? getNoteForDay(String linkedNodeId) =>
      _noteService.getNoteForDay(linkedNodeId);

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

  List<Note> get inboxNotes =>
      _noteService.inboxNotes;

  // ---------- Стандартные задачи ----------

  List<StandardTask> get standardTasks =>
      _standardTasksBox.values.toList();

  void addStandardTask(StandardTask task) {
    _standardTasksBox.put(task.id, task);

    notifyListeners();
  }

  void updateStandardTask(
      String id,
      StandardTask task,
      ) {
    _standardTasksBox.put(id, task);

    notifyListeners();
  }

  void deleteStandardTask(String id) {
    _standardTasksBox.delete(id);

    notifyListeners();
  }

  // ---------- Отслеживаемые задачи ----------

  List<TrackedActivity> get trackedActivities =>
      _trackedActivitiesBox.values.toList();

  void addTrackedActivity(
      TrackedActivity activity,
      ) {
    _trackedActivitiesBox.put(
      activity.id,
      activity,
    );

    notifyListeners();
  }

  void updateTrackedActivity(
      String id,
      TrackedActivity activity,
      ) {
    _trackedActivitiesBox.put(
      id,
      activity,
    );

    notifyListeners();
  }

  void deleteTrackedActivity(String id) {
    _trackedActivitiesBox.delete(id);

    notifyListeners();
  }

  // ---------- Внешнее уведомление ----------

  void notify() {
    notifyListeners();
  }
}