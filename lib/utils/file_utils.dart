import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import '../models/node.dart';

class FileUtils {
  static Future<void> exportTemplate(Node template) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          '${template.name}_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');

      final jsonString = jsonEncode(template.toJson());
      await file.writeAsString(jsonString);

      debugPrint('Шаблон сохранён: ${file.path}');
    } catch (e) {
      throw Exception('Ошибка экспорта: $e');
    }
  }

  static Future<void> exportAllTemplates(List<Node> templates) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'all_books_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');

      final jsonArray = templates.map((t) => t.toJson()).toList();
      final jsonString = jsonEncode(jsonArray);
      await file.writeAsString(jsonString);

      debugPrint('Все книги сохранены: ${file.path}');
    } catch (e) {
      throw Exception('Ошибка экспорта всех книг: $e');
    }
  }

  static Future<Node?> importTemplate() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final fileBytes = result.files.first.bytes;

        if (fileBytes != null) {
          final jsonString = utf8.decode(fileBytes);
          final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
          return Node.fromJson(jsonMap);
        } else {
          final filePath = result.files.first.path;
          if (filePath != null) {
            final file = File(filePath);
            final jsonString = await file.readAsString();
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
}
