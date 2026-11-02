import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
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

  // Close only the boxes opened during this startup attempt if a later step
  // fails. Hive.close() is global and would invalidate every earlier box.
  final openedBoxClosers = <Future<void> Function()>[];

  Future<Box<T>> openBox<T>(String name) async {
    final box = await Hive.openBox<T>(name);
    openedBoxClosers.add(() => box.close());
    return box;
  }

  try {
    await Hive.initFlutter();

    Hive.registerAdapter(NodeAdapter());
    Hive.registerAdapter(AppSettingsAdapter());
    Hive.registerAdapter(HistoryEntryAdapter());
    Hive.registerAdapter(NoteAdapter());
    Hive.registerAdapter(StandardTaskAdapter());
    Hive.registerAdapter(TrackedActivityAdapter());

    final templatesBox = await openBox<Node>('templates');
    final settingsBox = await openBox<AppSettings>('settings');
    final historyBox = await openBox<HistoryEntry>('history');
    final notesBox = await openBox<Note>('notes');
    final standardTasksBox = await openBox<StandardTask>('standard_tasks');
    final trackedActivitiesBox =
        await openBox<TrackedActivity>('tracked_activities');

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
  } catch (error, stackTrace) {
    debugPrint('Ошибка инициализации локального хранилища: $error');
    debugPrintStack(stackTrace: stackTrace);

    // Preserve every original Hive file. A failed open is not sufficient
    // evidence that the box is corrupt, so recovery must not rename files.
    for (final closeBox in openedBoxClosers.reversed) {
      try {
        await closeBox();
      } catch (closeError) {
        debugPrint('Не удалось закрыть бокс после ошибки запуска: $closeError');
      }
    }

    runApp(StartupErrorApp(error: error));
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
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
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

/// Shown when startup cannot safely open all local boxes. No Hive data is
/// modified or moved, so the user can close the app and seek help recovering
/// the original files instead of unknowingly continuing with empty storage.
class StartupErrorApp extends StatelessWidget {
  final Object error;

  const StartupErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Book Planner',
      home: Scaffold(
        appBar: AppBar(title: const Text('Book Planner')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.storage_rounded,
                  size: 48,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  'Не удалось открыть локальные данные',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Приложение не запущено, чтобы не повредить ваши данные. '
                  'Файлы хранилища не удалялись и не перемещались. '
                  'Закройте приложение и обратитесь за помощью с диагностикой '
                  'ошибки перед попыткой восстановления.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SelectableText(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
