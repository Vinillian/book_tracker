import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/node.dart';
import 'models/settings.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(NodeAdapter());
  Hive.registerAdapter(AppSettingsAdapter());
  await Hive.openBox<Node>('templates');
  await Hive.openBox<AppSettings>('settings');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Box<AppSettings> settingsBox;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    settingsBox = Hive.box<AppSettings>('settings');
    _loadTheme();
  }

  void _loadTheme() {
    final settings = settingsBox.get('appSettings');
    if (settings != null) {
      switch (settings.themeMode) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        default:
          _themeMode = ThemeMode.system;
      }
    } else {
      settingsBox.put('appSettings', AppSettings(themeMode: 'system'));
    }
  }

  void _updateTheme(String mode) {
    setState(() {
      switch (mode) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        default:
          _themeMode = ThemeMode.system;
      }
    });
    settingsBox.put('appSettings', AppSettings(themeMode: mode));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Book Tracker',
      theme: ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _themeMode,
      home: HomeScreen(onThemeChanged: _updateTheme),
      debugShowCheckedModeBanner: false,
    );
  }
}
