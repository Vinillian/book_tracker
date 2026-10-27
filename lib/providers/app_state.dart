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
import '../utils/node_copy.dart';
import '../utils/plan_date.dart';
import '../utils/plan_generator.dart';
import '../utils/work_schedule.dart';

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
    _loadWorkSchedule();

    _historyBox = historyBox;
    _standardTasksBox = standardTasksBox;
    _trackedActivitiesBox = trackedActivitiesBox;

    HistoryService.init(historyBox);

    _noteService = NoteService(notesBox);
    _nodeService = NodeService(templatesBox, _noteService);
    _nodeService.migratePlannedDates(); // #114
    _nodeService.migrateNestedBookCategories(); // #139

    _historyBox.watch().listen((_) => notifyListeners());
    _trackedActivitiesBox.watch().listen((_) => notifyListeners());
  }

  void _loadTheme() {
    final settings = _settingsBox.get('appSettings');
    _themeMode = settings?.themeMode ?? 'system';
  }

  WorkSchedule? _workSchedule;

  /// The work schedule, or null when none is set (#144).
  WorkSchedule? get workSchedule => _workSchedule;

  /// Work day / day off for [date]; null when no schedule is set.
  DayType? dayTypeOf(DateTime date) => _workSchedule?.dayTypeOf(date);

  void _loadWorkSchedule() {
    final settings = _settingsBox.get('appSettings');
    _workSchedule = WorkSchedule.tryParse(settings?.workSchedule);
  }

  void setWorkSchedule(WorkSchedule? schedule) {
    _workSchedule = schedule;
    final settings =
        _settingsBox.get('appSettings') ?? AppSettings(themeMode: _themeMode);
    settings.workSchedule = schedule?.encode();
    _settingsBox.put('appSettings', settings);
    notifyListeners();
  }

  void setThemeMode(String mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    final settings = _settingsBox.get('appSettings') ?? AppSettings(themeMode: mode);
    settings.themeMode = mode;
    _settingsBox.put('appSettings', settings);
    notifyListeners();
  }

  Box<Node> get templatesBox => _nodeService.box;
  Box<Note> get notesBox => _noteService.box;
  Box<HistoryEntry> get historyBox => _historyBox;
  Box<StandardTask> get standardTasksBox => _standardTasksBox;
  Box<TrackedActivity> get trackedActivitiesBox => _trackedActivitiesBox;

  // Узлы, скрытые из списков на время окна «Отменить». Физически они
  // остаются в Hive до commitNodeDeletion, так что закрытие приложения
  // в этот момент ничего не теряет.
  final Set<String> _pendingDeleteIds = {};

  List<Node> _visible(List<Node> nodes) =>
      nodes.where((n) => !_pendingDeleteIds.contains(n.id)).toList();

  List<Node> get books => _visible(_nodeService.books);
  List<Node> get plans => _visible(_nodeService.plans);
  List<Node> get templates => _visible(_nodeService.templates);

  void addNode(Node node) { _nodeService.add(node); notifyListeners(); }
  void updateNode(dynamic key, Node node) { _nodeService.update(key, node); notifyListeners(); }
  void deleteNode(dynamic key) {
    _nodeService.delete(key);
    notifyListeners();
  }

  /// Шаг 1 удаления с «Отменить»: убрать узел из списков, ничего не стирая.
  void hideNodeForDeletion(Node node) {
    _pendingDeleteIds.add(node.id);
    notifyListeners();
  }

  /// «Отменить»: вернуть скрытый узел в списки.
  void restoreNode(Node node) {
    if (_pendingDeleteIds.remove(node.id)) notifyListeners();
  }

  /// Окно «Отменить» закрылось: удалить узел, его заметки и History.
  void commitNodeDeletion(Node node) {
    if (!_pendingDeleteIds.remove(node.id)) return;
    dynamic key;
    try {
      key = _nodeService.getKey(node);
    } on StateError {
      key = null; // уже удалён
    }
    if (key != null) _nodeService.delete(key);
    notifyListeners();
  }

  /// The same three steps as above for several nodes at once, with a single
  /// notification each (deleting plans for a period, #163).
  void hideNodesForDeletion(Iterable<Node> nodes) {
    _pendingDeleteIds.addAll(nodes.map((n) => n.id));
    notifyListeners();
  }

  void restoreNodes(Iterable<Node> nodes) {
    var changed = false;
    for (final node in nodes) {
      if (_pendingDeleteIds.remove(node.id)) changed = true;
    }
    if (changed) notifyListeners();
  }

  void commitNodesDeletion(Iterable<Node> nodes) {
    var changed = false;
    for (final node in nodes) {
      if (!_pendingDeleteIds.remove(node.id)) continue;
      changed = true;
      try {
        _nodeService.delete(_nodeService.getKey(node));
      } on StateError {
        // already gone
      }
    }
    if (changed) notifyListeners();
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

  /// Creates the days of [preview] from their templates (#145). A date that
  /// got a plan in the meantime is skipped, nothing is overwritten. Returns the
  /// created days so the caller can offer to undo the whole batch.
  List<Node> generatePlans(PlanGenerationPreview preview) {
    final taken = <DateTime>{};
    for (final plan in plans) {
      final date = planDateOf(plan);
      if (date != null) taken.add(date);
    }
    final created = <Node>[];
    for (final item in preview.toCreate) {
      if (taken.contains(item.date)) continue;
      created.add(_nodeService.addDayFromTemplate(item.template, item.date));
    }
    if (created.isNotEmpty) notifyListeners();
    return created;
  }

  /// Deletes days made by [generatePlans] (the "Undo" of the whole batch),
  /// with their notes and History.
  void removeGeneratedDays(Iterable<Node> days) {
    for (final day in days) {
      try {
        _nodeService.delete(_nodeService.getKey(day));
      } on StateError {
        // already gone
      }
    }
    notifyListeners();
  }

  /// Adds reset copies of the tasks of [source] (a template or another day) to
  /// the existing day [target] and saves it (#117). Returns how many tasks
  /// were added.
  int appendTasksToDay(Node target, Node source) {
    final copies = [for (final c in source.children) copyAndReset(c)];
    if (copies.isEmpty) return 0;
    target.children.addAll(copies);
    _nodeService.update(_nodeService.getKey(target), target);
    notifyListeners();
    return copies.length;
  }

  /// The visible day plan for [date] (by `plannedDate`, see #114).
  Node? planForDate(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    for (final plan in plans) {
      if (planDateOf(plan) == key) return plan;
    }
    return null;
  }

  bool planExistsForDate(DateTime date) => planForDate(date) != null;
  Node? getNodeById(String id) => _nodeService.getById(id);
  dynamic getKeyForNode(Node node) => _nodeService.getKey(node);

  Note? getNoteForDay(String linkedNodeId) => _noteService.getNoteForDay(linkedNodeId);
  /// Silent on purpose (no notifyListeners): called from DayNoteCard.initState.
  Note getOrCreateNoteForDay(String linkedNodeId) =>
      _noteService.getOrCreateNoteForDay(linkedNodeId);
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