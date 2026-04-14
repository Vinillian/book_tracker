import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/node.dart';

class FileUtils {
  /// Проверяет и запрашивает разрешение на запись во внешнее хранилище.
  /// Возвращает true, если доступ разрешён.
  static Future<bool> _requestStoragePermission() async {
    // На Android 11+ (API 30+) разрешение не требуется для доступа к
    // общедоступным папкам через Scoped Storage, но мы оставляем проверку
    // для старых версий.
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (status.isGranted) return true;
      final result = await Permission.storage.request();
      return result.isGranted;
    }
    // На iOS и других платформах разрешение не требуется
    return true;
  }

  /// Возвращает путь к папке "Documents/Book Planner".
  /// Создаёт папку, если её нет.
  static Future<Directory> _getExportDirectory() async {
    Directory directory;

    if (Platform.isAndroid) {
      // getExternalStorageDirectory() на Android возвращает путь к
      // /storage/emulated/0/Android/data/com.example.book_tracker/files
      // Но нам нужна публичная папка Documents.
      // Используем getExternalStoragePublicDirectory (deprecated, но работает).
      // Альтернатива: использовать path_provider + ручной путь.
      final storage = await getExternalStorageDirectory();
      // Поднимаемся на уровень выше, к корню внешнего хранилища
      final root = Directory(storage!.path.split('Android')[0]);
      directory = Directory('${root.path}Documents/Book Planner');
    } else {
      // Для iOS/Windows/macOS/Linux используем папку документов приложения
      final docs = await getApplicationDocumentsDirectory();
      directory = Directory('${docs.path}/Book Planner');
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// Экспортирует один шаблон в файл JSON с кодировкой UTF-8 с BOM.
  static Future<void> exportTemplate(Node template) async {
    // Проверяем разрешение
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Нет разрешения на запись во внешнее хранилище');
    }

    try {
      final directory = await _getExportDirectory();
      final fileName =
          '${template.name}_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');

      final jsonString = jsonEncode(template.toJson());
      // Добавляем BOM (Byte Order Mark) для правильного определения UTF-8
      final bytes = utf8.encode('\uFEFF$jsonString');
      await file.writeAsBytes(bytes);

      debugPrint('Шаблон сохранён: ${file.path}');
    } catch (e) {
      throw Exception('Ошибка экспорта: $e');
    }
  }

  /// Экспортирует все книги в один файл JSON с кодировкой UTF-8 с BOM.
  static Future<void> exportAllTemplates(List<Node> templates) async {
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Нет разрешения на запись во внешнее хранилище');
    }

    try {
      final directory = await _getExportDirectory();
      final fileName =
          'all_books_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');

      final jsonArray = templates.map((t) => t.toJson()).toList();
      final jsonString = jsonEncode(jsonArray);
      final bytes = utf8.encode('\uFEFF$jsonString');
      await file.writeAsBytes(bytes);

      debugPrint('Все книги сохранены: ${file.path}');
    } catch (e) {
      throw Exception('Ошибка экспорта всех книг: $e');
    }
  }

  /// Импорт шаблона из JSON-файла, выбранного пользователем.
  static Future<Node?> importTemplate() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final fileBytes = result.files.first.bytes;

        if (fileBytes != null) {
          final jsonString = _decodeWithBom(fileBytes);
          final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
          return Node.fromJson(jsonMap);
        } else {
          final filePath = result.files.first.path;
          if (filePath != null) {
            final file = File(filePath);
            final fileBytes = await file.readAsBytes();
            final jsonString = _decodeWithBom(fileBytes);
            final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
            return Node.fromJson(jsonMap);
          } else {
            throw Exception('Не удалось прочитать файл: нет ни bytes, ни path');
          }
        }
      }
    } catch (e) {
      throw Exception('Ошибка импорта: $e');
    }
    return null;
  }

  /// Декодирует UTF-8, удаляя BOM, если он присутствует.
  static String _decodeWithBom(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      // Есть BOM – удаляем первые 3 байта
      return utf8.decode(bytes.sublist(3));
    }
    return utf8.decode(bytes);
  }
}
