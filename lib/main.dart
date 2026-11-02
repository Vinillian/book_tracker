import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'providers/app_state.dart';
import 'services/hive_startup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Hive.initFlutter();
    registerAppHiveAdapters();

    final boxes = await HiveStartup(
      openBox: <T>(String name) => Hive.openBox<T>(name),
      onCloseError: (error) =>
          debugPrint('Не удалось закрыть бокс после ошибки запуска: $error'),
    ).open();

    runApp(
      ChangeNotifierProvider(
        create: (_) => AppState(
          templatesBox: boxes.templatesBox,
          notesBox: boxes.notesBox,
          historyBox: boxes.historyBox,
          standardTasksBox: boxes.standardTasksBox,
          trackedActivitiesBox: boxes.trackedActivitiesBox,
          settingsBox: boxes.settingsBox,
        ),
        child: const MyApp(),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('Ошибка инициализации локального хранилища: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(StartupErrorApp(error: error));
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
