import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/node.dart';
import 'models/settings.dart';
import 'models/history_entry.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(NodeAdapter());
  Hive.registerAdapter(AppSettingsAdapter());
  Hive.registerAdapter(HistoryEntryAdapter());

  // Открываем бокс для книг
  try {
    await Hive.openBox<Node>('templates');
  } catch (e) {
    print('Ошибка открытия templates, удаляем и создаём новый');
    await Hive.deleteBoxFromDisk('templates');
    await Hive.openBox<Node>('templates');
  }

  // Открываем бокс для настроек
  await Hive.openBox<AppSettings>('settings');

  // Открываем бокс для истории
  await Hive.openBox<HistoryEntry>('history');

  runApp(const MyApp());
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
    setState(() {
      _themeMode = mode;
    });
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