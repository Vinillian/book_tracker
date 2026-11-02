import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/history_entry.dart';
import '../models/node.dart';
import '../models/note.dart';
import '../models/settings.dart';
import '../models/standard_task.dart';
import '../models/tracked_activity.dart';
import 'history_service.dart';
import 'node_service.dart';
import 'note_service.dart';

typedef HiveBoxOpener = Future<Box<T>> Function<T>(String name);

class HiveBoxNames {
  final String templates;
  final String settings;
  final String history;
  final String notes;
  final String standardTasks;
  final String trackedActivities;

  const HiveBoxNames({
    this.templates = 'templates',
    this.settings = 'settings',
    this.history = 'history',
    this.notes = 'notes',
    this.standardTasks = 'standard_tasks',
    this.trackedActivities = 'tracked_activities',
  });

  factory HiveBoxNames.prefixed(String prefix) => HiveBoxNames(
        templates: '${prefix}_templates',
        settings: '${prefix}_settings',
        history: '${prefix}_history',
        notes: '${prefix}_notes',
        standardTasks: '${prefix}_standard_tasks',
        trackedActivities: '${prefix}_tracked_activities',
      );
}

class OpenedHiveBoxes {
  final Box<Node> templatesBox;
  final Box<AppSettings> settingsBox;
  final Box<HistoryEntry> historyBox;
  final Box<Note> notesBox;
  final Box<StandardTask> standardTasksBox;
  final Box<TrackedActivity> trackedActivitiesBox;

  const OpenedHiveBoxes({
    required this.templatesBox,
    required this.settingsBox,
    required this.historyBox,
    required this.notesBox,
    required this.standardTasksBox,
    required this.trackedActivitiesBox,
  });
}

void registerAppHiveAdapters() {
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(NodeAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(AppSettingsAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(HistoryEntryAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(NoteAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(StandardTaskAdapter());
  if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(TrackedActivityAdapter());
}

/// Opens each required box once. If a later box or migration fails, only boxes
/// opened by this attempt are closed, in reverse order. Original files are
/// never moved or deleted because an open error alone does not prove damage.
class HiveStartup {
  final HiveBoxOpener openBox;
  final HiveBoxNames names;
  final void Function(Object error)? onCloseError;

  const HiveStartup({
    required this.openBox,
    this.names = const HiveBoxNames(),
    this.onCloseError,
  });

  Future<OpenedHiveBoxes> open() async {
    final closers = <Future<void> Function()>[];

    Future<Box<T>> openTracked<T>(String name) async {
      final box = await openBox<T>(name);
      closers.add(() => box.close());
      return box;
    }

    try {
      final templates = await openTracked<Node>(names.templates);
      final settings = await openTracked<AppSettings>(names.settings);
      final history = await openTracked<HistoryEntry>(names.history);
      final notes = await openTracked<Note>(names.notes);
      final standardTasks = await openTracked<StandardTask>(names.standardTasks);
      final trackedActivities =
          await openTracked<TrackedActivity>(names.trackedActivities);

      // NodeService.update may clean history for removed ids.
      HistoryService.init(history);
      migrateLegacyPlanIds(templates, notes);

      return OpenedHiveBoxes(
        templatesBox: templates,
        settingsBox: settings,
        historyBox: history,
        notesBox: notes,
        standardTasksBox: standardTasks,
        trackedActivitiesBox: trackedActivities,
      );
    } catch (_) {
      for (final closeBox in closers.reversed) {
        try {
          await closeBox();
        } catch (closeError) {
          try {
            onCloseError?.call(closeError);
          } catch (_) {
            // Diagnostics must not mask the startup error.
          }
        }
      }
      rethrow;
    }
  }
}

/// Replaces reserved IDs on legacy day plans with unique IDs.
/// Returns the number of updated plans; running it again changes nothing.
int migrateLegacyPlanIds(Box<Node> templatesBox, Box<Note> notesBox) {
  final nodeService = NodeService(templatesBox, NoteService(notesBox));
  var updated = 0;

  for (final plan in nodeService.plans) {
    if (plan.id.isEmpty ||
        plan.id == 'template-workday' ||
        plan.id == 'template-restday') {
      final key = nodeService.getKey(plan);
      if (key != null) {
        plan.id = const Uuid().v4();
        nodeService.update(key, plan);
        updated++;
      }
    }
  }

  return updated;
}
