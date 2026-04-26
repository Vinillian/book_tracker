import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'models/node.dart';
import 'models/settings.dart';
import 'models/history_entry.dart';
import 'models/note.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(NodeAdapter());
  Hive.registerAdapter(AppSettingsAdapter());
  Hive.registerAdapter(HistoryEntryAdapter());
  Hive.registerAdapter(NoteAdapter());

  // Открываем бокс для книг и планов
  try {
    await Hive.openBox<Node>('templates');
  } catch (e) {
    debugPrint('Ошибка открытия templates: $e');
    await Hive.close();
    final appDir = await getApplicationDocumentsDirectory();
    final hiveDir = Directory('${appDir.path}/app_flutter');
    final filesToDelete = [
      '${hiveDir.path}/templates.hive',
      '${hiveDir.path}/templates.lock',
    ];
    for (final filePath in filesToDelete) {
      try {
        final file = File(filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    await Hive.openBox<Node>('templates');
  }

  try {
    await Hive.openBox<AppSettings>('settings');
  } catch (e) {
    debugPrint('Ошибка открытия settings: $e');
    await Hive.close();
    final appDir = await getApplicationDocumentsDirectory();
    final hiveDir = Directory('${appDir.path}/app_flutter');
    final filesToDelete = [
      '${hiveDir.path}/settings.hive',
      '${hiveDir.path}/settings.lock',
    ];
    for (final filePath in filesToDelete) {
      try {
        final file = File(filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    await Hive.openBox<AppSettings>('settings');
  }

  try {
    await Hive.openBox<HistoryEntry>('history');
  } catch (e) {
    debugPrint('Ошибка открытия history: $e');
    await Hive.close();
    final appDir = await getApplicationDocumentsDirectory();
    final hiveDir = Directory('${appDir.path}/app_flutter');
    final filesToDelete = [
      '${hiveDir.path}/history.hive',
      '${hiveDir.path}/history.lock',
    ];
    for (final filePath in filesToDelete) {
      try {
        final file = File(filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    await Hive.openBox<HistoryEntry>('history');
  }

  try {
    await Hive.openBox<Note>('notes');
  } catch (e) {
    debugPrint('Ошибка открытия notes: $e');
    await Hive.close();
    final appDir = await getApplicationDocumentsDirectory();
    final hiveDir = Directory('${appDir.path}/app_flutter');
    final filesToDelete = [
      '${hiveDir.path}/notes.hive',
      '${hiveDir.path}/notes.lock',
    ];
    for (final filePath in filesToDelete) {
      try {
        final file = File(filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    await Hive.openBox<Note>('notes');
  }

  // Миграция: выдаём уникальный ID всем существующим планам, у которых его нет или он равен шаблонным
  _migrateExistingPlans();

  runApp(const MyApp());
}

/// Однократная миграция старых планов — присваивает уникальный ID,
/// если он отсутствует или совпадает с идентификаторами шаблонов.
void _migrateExistingPlans() {
  final templatesBox = Hive.box<Node>('templates');
  final plans = templatesBox.values
      .where((n) => n.category == 'planner')
      .toList();

  for (final plan in plans) {
    if (plan.id.isEmpty ||
        plan.id == 'template-workday' ||
        plan.id == 'template-restday') {
      final newId = const Uuid().v4();
      final key = templatesBox.keys.firstWhere(
        (k) => templatesBox.get(k) == plan,
        orElse: () => null,
      );
      if (key != null) {
        plan.id = newId;
        templatesBox.put(key, plan);
      }
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Box<AppSettings> settingsBox;
  String _themeMode = 'system';

  @override
  void initState() {
    super.initState();
    settingsBox = Hive.box<AppSettings>('settings');
    _loadTheme();
  }

  void _loadTheme() {
    final settings = settingsBox.get('appSettings');
    if (settings != null) {
      _themeMode = settings.themeMode;
    } else {
      settingsBox.put('appSettings', AppSettings(themeMode: 'system'));
    }
  }

  void _updateTheme(String mode) {
    setState(() => _themeMode = mode);
    final settings = settingsBox.get('appSettings');
    if (settings != null) {
      settings.themeMode = mode;
      settingsBox.put('appSettings', settings);
    } else {
      settingsBox.put('appSettings', AppSettings(themeMode: mode));
    }
  }

  ThemeMode _getThemeMode() {
    switch (_themeMode) {
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
      themeMode: _getThemeMode(),
      home: HomeScreen(
        onThemeChanged: _updateTheme,
        currentThemeMode: _themeMode,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
