import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_flutter/hive_flutter.dart';

class FileTransfer {
  /// === Публичный API (используется в приложении) ===

  static Future<bool> exportBox<T>({
    required Box<T> box,
    String? categoryFilter,
    String? suggestedName,
    bool Function(T item)? filter,
  }) async {
    final items = _filterItems(
      box,
      categoryFilter: categoryFilter,
      filter: filter,
    );
    if (items.isEmpty) {
      debugPrint('Нет данных для экспорта');
      return false;
    }
    final bytes = boxToJsonBytes(items);
    final name = suggestedName ?? 'export';
    final fileName = '${name}_${DateTime.now().millisecondsSinceEpoch}.json';

    return _exportFile(bytes, fileName);
  }

  static Future<int> importIntoBox<T>({
    required Box<T> box,
    required T Function(Map<String, dynamic>) fromJson,
    String? setCategory,
    bool skipDuplicates = true,
    bool Function(Map<String, dynamic>)? filterJson,
  }) async {
    final bytes = await _importFile();
    if (bytes == null) return 0;

    final items = jsonBytesToItems(bytes);
    if (items == null) return -1; // ошибка парсинга

    int imported = 0;
    for (final item in items) {
      if (filterJson != null && !filterJson(item)) continue;
      final obj = fromJson(item);
      if (setCategory != null) {
        try {
          (obj as dynamic).category = setCategory;
        } catch (_) {}
      }
      final objId = (obj as dynamic).id;
      if (skipDuplicates && objId != null) {
        final exists = box.values.any((e) {
          try {
            return (e as dynamic).id == objId;
          } catch (_) {
            return false;
          }
        });
        if (exists) continue;
      }
      await box.add(obj);
      imported++;
    }
    return imported;
  }

  /// === Вспомогательные чистые функции (доступны для тестирования) ===

  /// Преобразует список элементов в JSON-байты (с BOM)
  static Uint8List boxToJsonBytes<T>(List<T> items) {
    final jsonList = items.map((item) => (item as dynamic).toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    return Uint8List.fromList(utf8.encode('\uFEFF$jsonString'));
  }

  /// Парсит JSON-байты (с BOM или без) в список Map
  static List<Map<String, dynamic>>? jsonBytesToItems(Uint8List bytes) {
    String jsonString;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      jsonString = utf8.decode(bytes.sublist(3));
    } else {
      jsonString = utf8.decode(bytes);
    }
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      } else if (decoded is Map<String, dynamic>) {
        return [decoded];
      }
    } catch (e) {
      debugPrint('Ошибка парсинга JSON: $e');
    }
    return null;
  }

  /// === Приватные методы для работы с file_picker ===

  static List<T> _filterItems<T>(
    Box<T> box, {
    String? categoryFilter,
    bool Function(T)? filter,
  }) {
    var items = box.values.toList();
    if (filter != null) {
      items = items.where(filter).toList();
    } else if (categoryFilter != null) {
      items = items.where((item) {
        try {
          return (item as dynamic).category == categoryFilter;
        } catch (_) {
          return false;
        }
      }).toList();
    }
    return items;
  }

  static Future<bool> _exportFile(Uint8List bytes, String fileName) async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Сохранить файл',
      fileName: fileName,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    return result != null;
  }

  static Future<Uint8List?> _importFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    if (file.bytes != null) return file.bytes!;
    if (file.path != null) return await File(file.path!).readAsBytes();
    return null;
  }
}
