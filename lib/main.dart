import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/node.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(NodeAdapter());

  try {
    await Hive.openBox<Node>('templates');
    print('✅ Бокс "templates" открыт успешно');
  } catch (e) {
    print('❌ Ошибка при открытии бокса: $e');
    print('🔄 Удаляем старый бокс...');
    try {
      await Hive.deleteBoxFromDisk('templates');
      print('✅ Старый бокс удалён');
    } catch (deleteError) {
      print('⚠️ Не удалось удалить бокс (возможно, файла нет): $deleteError');
    }
    // Создаём новый чистый бокс
    await Hive.openBox<Node>('templates');
    print('✅ Новый бокс создан и открыт');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
