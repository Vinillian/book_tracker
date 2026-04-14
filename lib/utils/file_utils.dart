import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import '../models/node.dart';

class FileUtils {
  /// Экспортирует один шаблон в файл JSON с кодировкой UTF-8 с BOM.
  static Future<void> exportTemplate(Node template) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
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
    try {
      final directory = await getApplicationDocumentsDirectory();
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
