import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'models/node.dart';
import 'models/settings.dart';
import 'models/history_entry.dart';
import 'models/note.dart';
import 'models/standard_task.dart';
import 'models/tracked_activity.dart';
import 'screens/home_screen.dart';
import 'providers/app_state.dart';
import 'services/node_service.dart';
import 'services/note_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(NodeAdapter());
  Hive.registerAdapter(AppSettingsAdapter());
  Hive.registerAdapter(HistoryEntryAdapter());
  Hive.registerAdapter(NoteAdapter());
  Hive.registerAdapter(StandardTaskAdapter());
  Hive.registerAdapter(TrackedActivityAdapter());

  Box<Node> templatesBox = await _openBox<Node>('templates');
  Box<AppSettings> settingsBox = await _openBox<AppSettings>('settings');
  Box<HistoryEntry> historyBox = await _openBox<HistoryEntry>('history');
  Box<Note> notesBox = await _openBox<Note>('notes');
  Box<StandardTask> standardTasksBox = await _openBox<StandardTask>('standard_tasks');
  Box<TrackedActivity> trackedActivitiesBox = await _openBox<TrackedActivity>('tracked_activities');

  _migrateExistingPlans(templatesBox, notesBox);

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(
        templatesBox: templatesBox,
        notesBox: notesBox,
        historyBox: historyBox,
        standardTasksBox: standardTasksBox,
        trackedActivitiesBox: trackedActivitiesBox,
        settingsBox: settingsBox,
      ),
      child: const MyApp(),
    ),
  );
}

Future<Box<T>> _openBox<T>(String name) async {
  try {
    return await Hive.openBox<T>(name);
  } catch (e) {
    debugPrint('Ошибка открытия $name: $e');
    await Hive.close();
    final appDir = await getApplicationDocumentsDirectory();
    final hiveDir = Directory('${appDir.path}/app_flutter');
    final filesToDelete = [
      '${hiveDir.path}/$name.hive',
      '${hiveDir.path}/$name.lock',
    ];
    for (final filePath in filesToDelete) {
      try {
        final file = File(filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    return await Hive.openBox<T>(name);
  }
}

void _migrateExistingPlans(Box<Node> templatesBox, Box<Note> notesBox) {
  final noteService = NoteService(notesBox);
  final nodeService = NodeService(templatesBox, noteService);
  final plans = nodeService.plans;

  for (final plan in plans) {
    if (plan.id.isEmpty ||
        plan.id == 'template-workday' ||
        plan.id == 'template-restday') {
      final newId = const Uuid().v4();
      final key = nodeService.getKey(plan);
      if (key != null) {
        plan.id = newId;
        nodeService.update(key, plan);
      }
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeMode _getThemeMode(String mode) {
    switch (mode) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final themeMode = _getThemeMode(appState.themeMode);
        return MaterialApp(
          title: 'Book Planner',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.dark,
          ),
          themeMode: themeMode,
          home: const HomeScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}