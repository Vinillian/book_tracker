import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/node.dart';
import '../models/note.dart';
import '../models/history_entry.dart';
import '../models/standard_task.dart';
import '../models/tracked_activity.dart';

/// Диапазон дат, применяемый при экспорте категории (Plans/History) и
/// сохраняемый в файле как метаданные `exportedRange`.
/// Границы включительно, сравнение — по календарному дню (без времени).
class ExportDateRange {
  final DateTime start;
  final DateTime end;

  const ExportDateRange({required this.start, required this.end});

  Map<String, dynamic> toJson() => {
    'start': DateFormat('yyyy-MM-dd').format(start),
    'end': DateFormat('yyyy-MM-dd').format(end),
  };

  static ExportDateRange? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final startStr = json['start'];
    final endStr = json['end'];
    if (startStr is! String || endStr is! String) return null;
    try {
      return ExportDateRange(
        start: DateTime.parse(startStr),
        end: DateTime.parse(endStr),
      );
    } catch (_) {
      return null;
    }
  }

  bool contains(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !day.isBefore(s) && !day.isAfter(e);
  }
}

/// Результат разбора файла категории: как envelope-формата (schemaVersion 1+),
/// так и старого "голого массива" (schemaVersion 0, для обратной совместимости).
class CategoryEnvelope {
  final int schemaVersion;
  final String? category;
  final ExportDateRange? exportedRange;
  final List<Map<String, dynamic>> items;

  const CategoryEnvelope({
    required this.schemaVersion,
    this.category,
    this.exportedRange,
    required this.items,
  });
}

class FileTransfer {
  // ======================= Общие утилиты =======================

  static String? _bytesToJsonString(Uint8List bytes) {
    try {
      if (bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF) {
        return utf8.decode(bytes.sublist(3));
      }
      return utf8.decode(bytes);
    } catch (e) {
      debugPrint('Ошибка декодирования файла: $e');
      return null;
    }
  }

  /// Дата плана (дня) не хранится отдельным полем — она зашита в `Node.name`
  /// в формате dd.MM.yyyy (см. BookScreen._parsePlanDate). Строгий парсинг,
  /// несовпадающий формат — null (план не попадёт в date-range фильтр).
  static DateTime? planDateFromNode(Node node) {
    try {
      return DateFormat('dd.MM.yyyy').parseStrict(node.name);
    } catch (_) {
      return null;
    }
  }

  static Uint8List boxToJsonBytes<T>(List<T> items) {
    final jsonList = items.map((item) => (item as dynamic).toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    return Uint8List.fromList(utf8.encode('\uFEFF$jsonString'));
  }

  /// Используется только полным бэкапом (exportAll/importAll) — там верхний
  /// уровень файла это единственный объект {templates, notes, history, ...},
  /// а не список отдельных сущностей одной категории.
  static List<Map<String, dynamic>>? jsonBytesToItems(Uint8List bytes) {
    final jsonString = _bytesToJsonString(bytes);
    if (jsonString == null) return null;
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is List) return decoded.cast<Map<String, dynamic>>();
      if (decoded is Map<String, dynamic>) return [decoded];
    } catch (e) {
      debugPrint('Ошибка парсинга JSON: $e');
    }
    return null;
  }

  /// Кодирует список сущностей одной категории в envelope-формат:
  /// { schemaVersion, category, exportedRange?, items }
  static Uint8List categoryToJsonBytes({
    required String category,
    required List<Map<String, dynamic>> items,
    ExportDateRange? exportedRange,
  }) {
    final envelope = {
      'schemaVersion': 1,
      'category': category,
      if (exportedRange != null) 'exportedRange': exportedRange.toJson(),
      'items': items,
    };
    final jsonString = jsonEncode(envelope);
    return Uint8List.fromList(utf8.encode('\uFEFF$jsonString'));
  }

  /// Разбирает файл категории. Понимает оба формата:
  /// - новый envelope: {schemaVersion, category, exportedRange?, items: [...]}
  /// - старый bare-array: [...] (schemaVersion считается 0, метаданных нет)
  /// Возвращает null, если файл повреждён или имеет неожиданную структуру.
  static CategoryEnvelope? parseCategoryEnvelope(Uint8List bytes) {
    final jsonString = _bytesToJsonString(bytes);
    if (jsonString == null) return null;
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return CategoryEnvelope(
          schemaVersion: 0,
          items: decoded.cast<Map<String, dynamic>>(),
        );
      }
      if (decoded is Map<String, dynamic> && decoded['items'] is List) {
        return CategoryEnvelope(
          schemaVersion: decoded['schemaVersion'] is int
              ? decoded['schemaVersion'] as int
              : 1,
          category: decoded['category'] as String?,
          exportedRange: ExportDateRange.fromJson(
            decoded['exportedRange'] as Map<String, dynamic>?,
          ),
          items: (decoded['items'] as List).cast<Map<String, dynamic>>(),
        );
      }
    } catch (e) {
      debugPrint('Ошибка парсинга JSON: $e');
    }
    return null;
  }

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
    if (file.bytes != null) return file.bytes;
    if (file.path != null) return await File(file.path!).readAsBytes();
    return null;
  }

  // ======================= Экспорт/импорт по категориям =======================

  /// Экспорт одной категории в envelope-формате.
  /// [dateRange] + [dateExtractor] — опциональная фильтрация по датам
  /// (используется для Plans/History); для остальных категорий не передаются,
  /// экспортируется всё содержимое категории целиком, как раньше.
  static Future<bool> exportCategory<T>({
    required Box<T> box,
    required String category,
    String? categoryFilter,
    bool Function(T item)? filter,
    ExportDateRange? dateRange,
    DateTime? Function(T item)? dateExtractor,
    String? suggestedName,
  }) async {
    var items = _filterItems(box, categoryFilter: categoryFilter, filter: filter);

    if (dateRange != null) {
      if (dateExtractor == null) {
        debugPrint(
          'exportCategory("$category"): dateRange задан, но dateExtractor '
              'отсутствует — фильтр по дате пропущен',
        );
      } else {
        items = items.where((item) {
          final d = dateExtractor(item);
          return d != null && dateRange.contains(d);
        }).toList();
      }
    }

    if (items.isEmpty) {
      debugPrint('Нет данных для экспорта ($category)');
      return false;
    }

    final jsonItems = items
        .map((item) => (item as dynamic).toJson() as Map<String, dynamic>)
        .toList();
    final bytes = categoryToJsonBytes(
      category: category,
      items: jsonItems,
      exportedRange: dateRange,
    );
    final name = suggestedName ?? category;
    final fileName = '${name}_${DateTime.now().millisecondsSinceEpoch}.json';
    return _exportFile(bytes, fileName);
  }

  /// Импорт одной категории. Понимает оба формата файла (см. parseCategoryEnvelope).
  ///
  /// ВАЖНО: атомарность записи, валидация category envelope-а и выбор
  /// merge-стратегии (replace/add) — вне рамок этой функции, это #93.
  /// Здесь только замена источника парсинга (envelope вместо голого массива) —
  /// поведение самого import-цикла (skipDuplicates) не менялось.
  static Future<int> importIntoBox<T>({
    required Box<T> box,
    required T Function(Map<String, dynamic>) fromJson,
    String? setCategory,
    bool skipDuplicates = true,
    bool Function(Map<String, dynamic>)? filterJson,
  }) async {
    final bytes = await _importFile();
    if (bytes == null) return 0;
    final envelope = parseCategoryEnvelope(bytes);
    if (envelope == null) return -1;

    int imported = 0;
    for (final item in envelope.items) {
      if (filterJson != null && !filterJson(item)) continue;
      final obj = fromJson(item);
      if (setCategory != null) {
        try {
          (obj as dynamic).category = setCategory;
        } catch (_) {}
      }
      final objId = (obj as dynamic).id;
      if (skipDuplicates && objId != null) {
        bool exists = box.values.any((e) {
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

  // ======================= Полный бэкап и восстановление =======================
  // Не затронуто #92 — формат полного бэкапа отдельный от per-category envelope.

  static Future<bool> exportAll({
    required Box templatesBox,
    required Box notesBox,
    required Box historyBox,
    required Box standardTasksBox,
    required Box trackedActivitiesBox,
    String? suggestedName,
  }) async {
    final all = {
      'templates': templatesBox.values.map((e) => (e as dynamic).toJson()).toList(),
      'notes': notesBox.values.map((e) => (e as dynamic).toJson()).toList(),
      'history': historyBox.values.map((e) => (e as dynamic).toJson()).toList(),
      'standardTasks': standardTasksBox.values.map((e) => (e as dynamic).toJson()).toList(),
      'trackedActivities': trackedActivitiesBox.values.map((e) => (e as dynamic).toJson()).toList(),
    };
    final jsonString = jsonEncode(all);
    final bytes = Uint8List.fromList(utf8.encode('\uFEFF$jsonString'));
    final name = suggestedName ?? 'full_backup';
    final fileName = '${name}_${DateTime.now().millisecondsSinceEpoch}.json';
    return _exportFile(bytes, fileName);
  }

  static Future<bool> importAll({
    required Box templatesBox,
    required Box notesBox,
    required Box historyBox,
    required Box standardTasksBox,
    required Box trackedActivitiesBox,
  }) async {
    final bytes = await _importFile();
    if (bytes == null) return false;

    final items = jsonBytesToItems(bytes);
    if (items == null || items.isEmpty) return false;

    final data = items.first;
    // Основные поля должны быть (templates, notes, history)
    if (data['templates'] is! List ||
        data['notes'] is! List ||
        data['history'] is! List) {
      return false;
    }

    // Сначала парсим ВСЁ в память и ничего не трогаем в боксах.
    // Если хоть один элемент не распарсится — выходим здесь, до clear(),
    // и текущие данные пользователя остаются нетронутыми.
    late final List<Node> parsedTemplates;
    late final List<Note> parsedNotes;
    late final List<HistoryEntry> parsedHistory;
    late final List<StandardTask> parsedStandardTasks;
    late final List<TrackedActivity> parsedTrackedActivities;
    try {
      parsedTemplates = (data['templates'] as List)
          .map((t) => Node.fromJson(Map<String, dynamic>.from(t)))
          .toList();
      parsedNotes = (data['notes'] as List)
          .map((n) => Note.fromJson(Map<String, dynamic>.from(n)))
          .toList();
      parsedHistory = (data['history'] as List)
          .map((h) => HistoryEntry.fromJson(Map<String, dynamic>.from(h)))
          .toList();
      parsedStandardTasks = (data['standardTasks'] as List? ?? [])
          .map((st) => StandardTask.fromJson(Map<String, dynamic>.from(st)))
          .toList();
      parsedTrackedActivities = (data['trackedActivities'] as List? ?? [])
          .map((ta) => TrackedActivity.fromJson(Map<String, dynamic>.from(ta)))
          .toList();
    } catch (e) {
      debugPrint('Файл бэкапа повреждён, восстановление отменено: $e');
      return false;
    }

    // Файл валиден целиком — теперь можно безопасно очищать и записывать.
    await templatesBox.clear();
    await notesBox.clear();
    await historyBox.clear();
    await standardTasksBox.clear();
    await trackedActivitiesBox.clear();

    for (final t in parsedTemplates) {
      await templatesBox.add(t);
    }
    for (final n in parsedNotes) {
      await notesBox.add(n);
    }
    for (final h in parsedHistory) {
      await historyBox.add(h);
    }
    for (final st in parsedStandardTasks) {
      await standardTasksBox.add(st);
    }
    for (final ta in parsedTrackedActivities) {
      await trackedActivitiesBox.add(ta);
    }

    return true;
  }
}