import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class FileTransfer {
  /// Экспорт объектов из бокса в JSON-файл.
  /// Возвращает true, если файл сохранён успешно.
  static Future<bool> exportBox<T>({
    required Box<T> box,
    String? categoryFilter,
    String? suggestedName,
    bool Function(T item)? filter,
  }) async {
    // Получаем все объекты
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

    if (items.isEmpty) {
      debugPrint('Нет данных для экспорта');
      return false;
    }

    final jsonList = items.map((item) => (item as dynamic).toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    final bytes = utf8.encode('\uFEFF$jsonString');

    // Запрашиваем разрешение для Android
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        debugPrint('Нет разрешения на запись');
        return false;
      }
    }

    final name = suggestedName ?? 'export';
    final fileName = '${name}_${DateTime.now().millisecondsSinceEpoch}.json';

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Сохранить файл',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null) {
      final file = File(result);
      await file.writeAsBytes(bytes);
      return true;
    }
    return false;
  }

  /// Импорт объектов в бокс из JSON-файла.
  /// Возвращает количество импортированных элементов.
  static Future<int> importIntoBox<T>({
    required Box<T> box,
    required T Function(Map<String, dynamic>) fromJson,
    String? setCategory,
    bool skipDuplicates = true,
    bool Function(Map<String, dynamic>)? filterJson,
  }) async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        debugPrint('Нет разрешения на чтение');
        return 0;
      }
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) return 0;

    final file = result.files.first;
    Uint8List bytes;
    if (file.bytes != null) {
      bytes = file.bytes!;
    } else if (file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    } else {
      return 0;
    }

    String jsonString;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      jsonString = utf8.decode(bytes.sublist(3));
    } else {
      jsonString = utf8.decode(bytes);
    }

    final dynamic decoded = jsonDecode(jsonString);
    final List<dynamic> jsonList = (decoded is List) ? decoded : [decoded];

    int imported = 0;
    for (final item in jsonList) {
      if (item is! Map<String, dynamic>) continue;
      if (filterJson != null && !filterJson(item)) continue;

      final obj = fromJson(item);

      if (setCategory != null) {
        try {
          (obj as dynamic).category = setCategory;
        } catch (_) {}
      }

      final dynamic objId = (obj as dynamic).id;
      if (skipDuplicates && objId != null) {
        bool exists = box.values.any((existing) {
          try {
            return (existing as dynamic).id == objId;
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
}
