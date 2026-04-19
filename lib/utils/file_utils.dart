import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/node.dart';
import '../models/history_entry.dart';

class FileUtils {
  static Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (status.isGranted) return true;
      final result = await Permission.storage.request();
      return result.isGranted;
    }
    return true;
  }

  static Future<Directory> _getExportDirectory() async {
    Directory directory;

    if (Platform.isAndroid) {
      final storage = await getExternalStorageDirectory();
      final root = Directory(storage!.path.split('Android')[0]);
      directory = Directory('${root.path}Documents/Book Planner');
    } else {
      final docs = await getApplicationDocumentsDirectory();
      directory = Directory('${docs.path}/Book Planner');
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<void> exportTemplate(Node template) async {
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
      final bytes = utf8.encode('\uFEFF$jsonString');
      await file.writeAsBytes(bytes);

      debugPrint('Шаблон сохранён: ${file.path}');
    } catch (e) {
      throw Exception('Ошибка экспорта: $e');
    }
  }

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

  /// Импорт с возможностью добавления записей в историю
  static Future<Node?> importTemplate({bool addHistory = false}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final fileBytes = result.files.first.bytes;

        String jsonString;
        if (fileBytes != null) {
          jsonString = _decodeWithBom(fileBytes);
        } else {
          final filePath = result.files.first.path;
          if (filePath != null) {
            final file = File(filePath);
            final bytes = await file.readAsBytes();
            jsonString = _decodeWithBom(bytes);
          } else {
            throw Exception('Не удалось прочитать файл: нет ни bytes, ни path');
          }
        }

        final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
        final importedNode = Node.fromJson(jsonMap);

        if (addHistory) {
          await _generateHistoryFromNode(importedNode, importedNode.id);
        }

        return importedNode;
      }
    } catch (e) {
      throw Exception('Ошибка импорта: $e');
    }
    return null;
  }

  static String _decodeWithBom(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3));
    }
    return utf8.decode(bytes);
  }

  static Future<void> _generateHistoryFromNode(Node node, String bookId) async {
    final historyBox = Hive.box<HistoryEntry>('history');

    void traverse(Node n) {
      if (n.children.isEmpty && n.completed && !n.excludeFromHistory) {
        if (n.stepType == 'single') {
          final entry = HistoryEntry.forSingle(
            bookId: bookId,
            nodeId: n.id,
            nodeName: n.name,
            completed: true,
            date: n.plannedDate ?? DateTime.now(),
          );
          historyBox.add(entry);
        } else if (n.stepType == 'stepByStep' && n.completedSteps > 0) {
          final entry = HistoryEntry.forStep(
            bookId: bookId,
            nodeId: n.id,
            nodeName: n.name,
            completedSteps: n.completedSteps,
            date: n.plannedDate ?? DateTime.now(),
          );
          historyBox.add(entry);
        }
      }
      for (final child in n.children) {
        traverse(child);
      }
    }

    traverse(node);
  }
}
