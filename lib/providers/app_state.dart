import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/node.dart';
import '../models/note.dart';
import '../models/history_entry.dart';
import '../models/standard_task.dart';
import '../models/tracked_activity.dart';
import '../models/settings.dart';
import '../services/node_service.dart';
import '../services/note_service.dart';
import '../services/history_service.dart';

class AppState extends ChangeNotifier {
  late final NodeService _nodeService;
  late final NoteService _noteService;
  late final Box<HistoryEntry> _historyBox;
  late final Box<StandardTask> _standardTasksBox;
  late final Box<TrackedActivity> _trackedActivitiesBox;
  late final Box<AppSettings> _settingsBox;

  String _themeMode = 'system';

  String get themeMode => _themeMode;

  AppState({
    required Box<Node> templatesBox,
    required Box<Note> notesBox,
    required Box<HistoryEntry> historyBox,
    required Box<StandardTask> standardTasksBox,
    required Box<TrackedActivity> trackedActivitiesBox,
    required Box<AppSettings> settingsBox,
  }) {
    _settingsBox = settingsBox;
    _loadTheme();

    _historyBox = historyBox;
    _standardTasksBox = standardTasksBox;
    _trackedActivitiesBox = trackedActivitiesBox;

    HistoryService.init(historyBox);

    _noteService = NoteService(notesBox);
    _nodeService = NodeService(templatesBox, _noteService);

    _historyBox.watch().listen((_) => notifyListeners());
    _trackedActivitiesBox.watch().listen((_) => notifyListeners());
  }

  void _loadTheme() {
    final settings = _settingsBox.get('appSettings');
    _themeMode = settings?.themeMode ?? 'system';
  }

  void setThemeMode(String mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    final settings = _settingsBox.get('appSettings') ?? AppSettings(themeMode: mode);
    settings.themeMode = mode;
    _settingsBox.put('appSettings', settings);
    notifyListeners();
  }

  // ---------- остальные методы без изменений ----------
  Box<Node> get templatesBox => _nodeService.box;
  Box<Note> get notesBox => _noteService.box;
  Box<HistoryEntry> get historyBox => _historyBox;
  Box<StandardTask> get standardTasksBox => _standardTasksBox;
  Box<TrackedActivity> get trackedActivitiesBox => _trackedActivitiesBox;

  List<Node> get books => _nodeService.books;
  List<Node> get plans => _nodeService.plans;
  List<Node> get templates => _nodeService.templates;

  void addNode(Node node) { _nodeService.add(node); notifyListeners(); }
  void updateNode(dynamic key, Node node) { _nodeService.update(key, node); notifyListeners(); }
  void deleteNode(dynamic key) { _nodeService.delete(key); notifyListeners(); }

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

  List<StandardTask> get standardTasks => _standardTasksBox.values.toList();

  void addStandardTask(StandardTask task) {
    _standardTasksBox.put(task.id, task);
    notifyListeners();
  }

  void updateStandardTask(String id, StandardTask task) {
    dynamic keyToUpdate;
    for (var key in _standardTasksBox.keys) {
      final existing = _standardTasksBox.get(key);
      if (existing != null && existing.id == id) {
        keyToUpdate = key;
        break;
      }
    }
    if (keyToUpdate != null) {
      _standardTasksBox.put(keyToUpdate, task);
      notifyListeners();
    }
  }

  void deleteStandardTask(String id) {
    dynamic keyToDelete;
    for (var key in _standardTasksBox.keys) {
      final task = _standardTasksBox.get(key);
      if (task != null && task.id == id) {
        keyToDelete = key;
        break;
      }
    }
    if (keyToDelete != null) {
      _standardTasksBox.delete(keyToDelete);
      notifyListeners();
    }
  }

  List<TrackedActivity> get trackedActivities => _trackedActivitiesBox.values.toList();

  void addTrackedActivity(TrackedActivity activity) {
    _trackedActivitiesBox.put(activity.id, activity);
    notifyListeners();
  }

  void updateTrackedActivity(String id, TrackedActivity activity) {
    dynamic keyToUpdate;
    for (var key in _trackedActivitiesBox.keys) {
      final existing = _trackedActivitiesBox.get(key);
      if (existing != null && existing.id == id) {
        keyToUpdate = key;
        break;
      }
    }
    if (keyToUpdate != null) {
      _trackedActivitiesBox.put(keyToUpdate, activity);
      notifyListeners();
    }
  }

  void deleteTrackedActivity(String id) {
    dynamic keyToDelete;
    for (var key in _trackedActivitiesBox.keys) {
      final activity = _trackedActivitiesBox.get(key);
      if (activity != null && activity.id == id) {
        keyToDelete = key;
        break;
      }
    }
    if (keyToDelete != null) {
      _trackedActivitiesBox.delete(keyToDelete);
      notifyListeners();
    }
  }

  void notify() => notifyListeners();
}