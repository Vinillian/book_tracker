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
import 'plan_date.dart';
import 'work_schedule.dart';

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

/// Стратегия слияния при импорте одной категории.
/// Какие категории вообще позволяют выбор — решает экран (см. design table
/// в milestone v1.2.0): Books/Templates/Notes всегда addOnly без UI-выбора,
/// StandardTasks/TrackedActivities дают пользователю выбор, Plans/History
/// получат отдельную scoped-по-диапазону стратегию в #94.
enum ImportMergeStrategy { addOnly, replaceWholeList }

/// Итог одной попытки импорта — вместо магических int-кодов (-1/0/N),
/// которые были раньше.
enum ImportStatus { success, empty, malformed, categoryMismatch }

class ImportResult {
  final ImportStatus status;
  final int count;
  final String? expectedCategory;
  final String? actualCategory;

  const ImportResult({
    required this.status,
    this.count = 0,
    this.expectedCategory,
    this.actualCategory,
  });
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

/// Разобранный общий файл планов и истории (#168).
class PlansHistoryFile {
  final ExportDateRange? exportedRange;
  final List<Map<String, dynamic>> plans;
  final List<Map<String, dynamic>> history;

  const PlansHistoryFile({
    this.exportedRange,
    required this.plans,
    required this.history,
  });
}

class FileTransfer {
  // ======================= Общие утилиты =======================

  /// Магические байты gzip-потока (RFC 1952). Используются, чтобы отличить
  /// сжатый файл (#100) от старого plain-JSON/BOM файла на импорте —
  /// без привязки к расширению файла (оно всегда остаётся .json).
  static const int _gzipMagic0 = 0x1f;
  static const int _gzipMagic1 = 0x8b;

  static bool _looksGzipped(Uint8List bytes) =>
      bytes.length >= 2 && bytes[0] == _gzipMagic0 && bytes[1] == _gzipMagic1;

  static String? _bytesToJsonString(Uint8List bytes) {
    // #100: если файл gzip-сжат — сначала распаковать. Старые (несжатые)
    // бэкапы magic bytes не имеют и идут дальше без изменений (обратная
    // совместимость сохраняется автоматически).
    if (_looksGzipped(bytes)) {
      try {
        bytes = Uint8List.fromList(gzip.decode(bytes));
      } catch (e) {
        debugPrint('Ошибка распаковки gzip: $e');
        return null;
      }
    }
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

  /// Дата плана (дня): `Node.plannedDate`, для старых данных — имя в формате
  /// dd.MM.yyyy (см. planDateOf, #114). Нет даты — null (план не попадёт
  /// в date-range фильтр).
  static DateTime? planDateFromNode(Node node) => planDateOf(node);

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
    // #100: сжимаем перед записью на диск — JSON с повторяющимися ключами и
    // похожими строками обычно ужимается на 70-85%. Файл теперь получает
    // честное расширение .gz поверх .json (например history_123.json.gz) —
    // если оставить .json, а внутри бинарный gzip, некоторые Android-провайдеры
    // сами определяют реальный тип по содержимому и показывают файл серым/
    // некликабельным в системном диалоге выбора (расширение обещает JSON,
    // а по факту бинарные данные — несовпадение).
    final compressed = Uint8List.fromList(gzip.encode(bytes));
    final compressedName = '$fileName.gz';
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Сохранить файл',
      fileName: compressedName,
      bytes: compressed,
      type: FileType.custom,
      allowedExtensions: ['gz'],
    );
    return result != null;
  }

  static Future<Uint8List?> _importFile() async {
    // Разрешаем оба расширения: json — старые несжатые бэкапы (до #100),
    // gz — новые сжатые. Реальный формат содержимого всё равно определяется
    // по magic bytes в _bytesToJsonString, расширение здесь влияет только
    // на то, какие файлы система вообще позволит выбрать в диалоге.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'gz'],
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
  /// [expectedCategory] — категория, которую ожидает данный экран (например
  /// 'standardTask'). Если файл несёт метаданные envelope и его `category`
  /// не совпадает — импорт отклоняется до записи (categoryMismatch).
  /// Старые bare-array файлы (envelope.category == null) метаданных не несут,
  /// поэтому валидация в этом случае не применяется — иначе мы бы сломали
  /// обратную совместимость, которую сознательно сохранили в #92.
  ///
  /// Двухфазно: сначала весь `fromJson` в память (Phase 1), и только если
  /// ВСЕ элементы распарсились успешно — запись в box (Phase 2). Если файл
  /// повреждён посередине, текущие данные пользователя не тронуты.
  static Future<ImportResult> importIntoBox<T>({
    required Box<T> box,
    required T Function(Map<String, dynamic>) fromJson,
    required String expectedCategory,
    String? setCategory,
    ImportMergeStrategy mergeStrategy = ImportMergeStrategy.addOnly,
    bool Function(Map<String, dynamic>)? filterJson,
  }) async {
    final bytes = await _importFile();
    if (bytes == null) return const ImportResult(status: ImportStatus.empty);

    final envelope = parseCategoryEnvelope(bytes);
    if (envelope == null) {
      return const ImportResult(status: ImportStatus.malformed);
    }

    if (envelope.category != null && envelope.category != expectedCategory) {
      return ImportResult(
        status: ImportStatus.categoryMismatch,
        expectedCategory: expectedCategory,
        actualCategory: envelope.category,
      );
    }

    // Phase 1: парсинг всего файла в память. Box пока не тронут.
    final List<T> parsed = [];
    try {
      for (final item in envelope.items) {
        if (filterJson != null && !filterJson(item)) continue;
        final obj = fromJson(item);
        if (setCategory != null) {
          try {
            (obj as dynamic).category = setCategory;
          } catch (_) {}
        }
        parsed.add(obj);
      }
    } catch (e) {
      debugPrint('Ошибка парсинга элементов импорта ($expectedCategory): $e');
      return const ImportResult(status: ImportStatus.malformed);
    }

    if (parsed.isEmpty) {
      return const ImportResult(status: ImportStatus.empty);
    }

    // Phase 2: запись. Только теперь данные в box реально меняются.
    int imported = 0;
    if (mergeStrategy == ImportMergeStrategy.replaceWholeList) {
      await box.clear();
      for (final obj in parsed) {
        await box.add(obj);
        imported++;
      }
    } else {
      final existingIds = box.values
          .map((e) {
        try {
          return (e as dynamic).id as String?;
        } catch (_) {
          return null;
        }
      })
          .whereType<String>()
          .toSet();

      for (final obj in parsed) {
        String? objId;
        try {
          objId = (obj as dynamic).id as String?;
        } catch (_) {}
        if (objId != null && existingIds.contains(objId)) continue;
        await box.add(obj);
        if (objId != null) existingIds.add(objId);
        imported++;
      }
    }

    return ImportResult(status: ImportStatus.success, count: imported);
  }

  // ======================= Планы и история одним файлом (#168) =======================

  /// Категория общего файла планов и истории.
  static const String plansHistoryCategory = 'plansHistory';

  /// Что попадёт в экспорт планов и истории за [range]: планы (category
  /// 'planner') с датой в диапазоне и записи Истории за дни диапазона.
  /// Без диапазона (null) — всё.
  static ({List<Node> plans, List<HistoryEntry> history}) selectPlansHistory({
    required Iterable<Node> templates,
    required Iterable<HistoryEntry> history,
    ExportDateRange? range,
  }) {
    final plans = <Node>[];
    for (final n in templates) {
      if (n.category != 'planner') continue;
      if (range != null) {
        final d = planDateFromNode(n);
        if (d == null || !range.contains(d)) continue;
      }
      plans.add(n);
    }
    final entries = <HistoryEntry>[
      for (final h in history)
        if (range == null || range.contains(h.date)) h,
    ];
    return (plans: plans, history: entries);
  }

  /// Общий файл: { schemaVersion, category: 'plansHistory', exportedRange?,
  /// plans, history }.
  static Uint8List plansHistoryToJsonBytes({
    required List<Map<String, dynamic>> plans,
    required List<Map<String, dynamic>> history,
    ExportDateRange? exportedRange,
  }) {
    final envelope = {
      'schemaVersion': 1,
      'category': plansHistoryCategory,
      if (exportedRange != null) 'exportedRange': exportedRange.toJson(),
      'plans': plans,
      'history': history,
    };
    return Uint8List.fromList(utf8.encode('\uFEFF${jsonEncode(envelope)}'));
  }

  /// Разбирает общий файл планов и истории. Null, если это не он (старый
  /// файл планов или истории, мусор) — вызывающий тогда пробует старый формат.
  static PlansHistoryFile? parsePlansHistoryFile(Uint8List bytes) {
    final text = _bytesToJsonString(bytes);
    if (text == null) return null;
    try {
      final dynamic decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic> ||
          decoded['category'] != plansHistoryCategory) {
        return null;
      }
      final plans = decoded['plans'];
      final history = decoded['history'];
      if (plans is! List || history is! List) return null;
      return PlansHistoryFile(
        exportedRange: ExportDateRange.fromJson(
          decoded['exportedRange'] as Map<String, dynamic>?,
        ),
        plans: plans.cast<Map<String, dynamic>>(),
        history: history.cast<Map<String, dynamic>>(),
      );
    } catch (e) {
      debugPrint('Ошибка парсинга файла планов и истории: $e');
      return null;
    }
  }

  /// Экспорт планов и истории одним файлом за [dateRange] (null = всё).
  static Future<bool> exportPlansWithHistory({
    required Box<Node> templatesBox,
    required Box<HistoryEntry> historyBox,
    ExportDateRange? dateRange,
  }) async {
    final selected = selectPlansHistory(
      templates: templatesBox.values,
      history: historyBox.values,
      range: dateRange,
    );
    if (selected.plans.isEmpty && selected.history.isEmpty) {
      debugPrint('Нет планов и истории для экспорта');
      return false;
    }
    final bytes = plansHistoryToJsonBytes(
      plans: [for (final p in selected.plans) p.toJson()],
      history: [for (final h in selected.history) h.toJson()],
      exportedRange: dateRange,
    );
    final fileName = 'plans_history_${DateTime.now().millisecondsSinceEpoch}.json';
    return _exportFile(bytes, fileName);
  }

  /// Записывает Планы и Историю в box'ы. Весь разбор уже сделан до вызова.
  ///
  /// Диапазон замены — [range] (из файла): заменяются только Планы, чья дата
  /// (planDateFromNode) в нём; без диапазона — все Планы. Если в файле нет
  /// Планов, ничего не удаляется, добавляется только История.
  ///
  /// История, связанная с заменяемыми Планами, удаляется ТОЧНО по nodeId
  /// (включая вложенные узлы), а не по дате — записи других Планов/Книг с
  /// той же датой не задеваются. Записи Истории, чей id уже есть в box,
  /// второй раз не добавляются (повторный импорт того же файла безопасен).
  ///
  /// Возвращает число записанных Планов + записей Истории.
  static Future<int> applyPlansWithHistory({
    required Box<Node> templatesBox,
    required Box<HistoryEntry> historyBox,
    required List<Node> plans,
    required List<HistoryEntry> history,
    ExportDateRange? range,
  }) async {
    // --- Какие существующие Планы попадают под замену ---
    final existingPlanKeys = <dynamic>[];
    final plansToRemove = <Node>[];
    if (plans.isNotEmpty) {
      for (final key in templatesBox.keys) {
        final n = templatesBox.get(key);
        if (n == null || n.category != 'planner') continue;
        if (range == null) {
          existingPlanKeys.add(key);
          plansToRemove.add(n);
        } else {
          final d = planDateFromNode(n);
          if (d != null && range.contains(d)) {
            existingPlanKeys.add(key);
            plansToRemove.add(n);
          }
        }
      }
    }

    // --- id всех узлов (включая дочерние) удаляемых Планов ---
    final deletedNodeIds = <String>{};
    void collectIds(Node n) {
      deletedNodeIds.add(n.id);
      for (final c in n.children) {
        collectIds(c);
      }
    }
    for (final p in plansToRemove) {
      collectIds(p);
    }

    // --- Удаляем старые Планы и связанную Историю ---
    await templatesBox.deleteAll(existingPlanKeys);
    final historyKeysToDelete = <dynamic>[];
    for (final key in historyBox.keys) {
      final h = historyBox.get(key);
      if (h != null && deletedNodeIds.contains(h.nodeId)) {
        historyKeysToDelete.add(key);
      }
    }
    await historyBox.deleteAll(historyKeysToDelete);

    // --- Записываем новые Планы и Историю ---
    for (final p in plans) {
      await templatesBox.add(p);
    }
    final knownIds = historyBox.values.map((h) => h.id).toSet();
    var addedHistory = 0;
    for (final h in history) {
      if (!knownIds.add(h.id)) continue;
      await historyBox.add(h);
      addedHistory++;
    }
    return plans.length + addedHistory;
  }

  /// Импорт Планов и Истории одной операцией (#94, #168).
  ///
  /// Новый формат — один файл с планами и историей (см.
  /// plansHistoryToJsonBytes). Старый формат тоже понимается: файл Планов, а
  /// после него второй файл — История (запрашивается следом).
  ///
  /// Файлы парсятся полностью в память до того, как box'ы будут тронуты —
  /// если что-то одно повреждено, ничего не меняется.
  static Future<ImportResult> importPlansWithHistory({
    required Box<Node> templatesBox,
    required Box<HistoryEntry> historyBox,
  }) async {
    final firstBytes = await _importFile();
    if (firstBytes == null) return const ImportResult(status: ImportStatus.empty);

    // --- Новый формат: всё в одном файле ---
    final combined = parsePlansHistoryFile(firstBytes);
    if (combined != null) {
      final List<Node> plans;
      final List<HistoryEntry> history;
      try {
        plans = combined.plans.map((j) {
          final n = Node.fromJson(j);
          n.category = 'planner';
          return n;
        }).toList();
        history = combined.history.map((j) => HistoryEntry.fromJson(j)).toList();
      } catch (e) {
        debugPrint('Ошибка парсинга файла планов и истории: $e');
        return const ImportResult(status: ImportStatus.malformed);
      }
      if (plans.isEmpty && history.isEmpty) {
        return const ImportResult(status: ImportStatus.empty);
      }
      final count = await applyPlansWithHistory(
        templatesBox: templatesBox,
        historyBox: historyBox,
        plans: plans,
        history: history,
        range: combined.exportedRange,
      );
      return ImportResult(status: ImportStatus.success, count: count);
    }

    // --- Старый формат: файл Планов, потом файл Истории ---
    final plansEnvelope = parseCategoryEnvelope(firstBytes);
    if (plansEnvelope == null) {
      return const ImportResult(status: ImportStatus.malformed);
    }
    if (plansEnvelope.category != null && plansEnvelope.category != 'planner') {
      return ImportResult(
        status: ImportStatus.categoryMismatch,
        expectedCategory: 'planner',
        actualCategory: plansEnvelope.category,
      );
    }

    final List<Node> parsedPlans;
    try {
      parsedPlans = plansEnvelope.items.map((j) {
        final n = Node.fromJson(j);
        n.category = 'planner';
        return n;
      }).toList();
    } catch (e) {
      debugPrint('Ошибка парсинга файла планов: $e');
      return const ImportResult(status: ImportStatus.malformed);
    }
    if (parsedPlans.isEmpty) {
      return const ImportResult(status: ImportStatus.empty);
    }

    final historyBytes = await _importFile();
    if (historyBytes == null) return const ImportResult(status: ImportStatus.empty);
    final historyEnvelope = parseCategoryEnvelope(historyBytes);
    if (historyEnvelope == null) {
      return const ImportResult(status: ImportStatus.malformed);
    }
    if (historyEnvelope.category != null && historyEnvelope.category != 'history') {
      return ImportResult(
        status: ImportStatus.categoryMismatch,
        expectedCategory: 'history',
        actualCategory: historyEnvelope.category,
      );
    }

    final List<HistoryEntry> parsedHistory;
    try {
      parsedHistory =
          historyEnvelope.items.map((j) => HistoryEntry.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Ошибка парсинга файла истории: $e');
      return const ImportResult(status: ImportStatus.malformed);
    }

    final count = await applyPlansWithHistory(
      templatesBox: templatesBox,
      historyBox: historyBox,
      plans: parsedPlans,
      history: parsedHistory,
      range: plansEnvelope.exportedRange,
    );
    return ImportResult(status: ImportStatus.success, count: count);
  }

  // ======================= Полный бэкап и восстановление =======================
  // Не затронуто #92 — формат полного бэкапа отдельный от per-category envelope.

  /// The object a full backup is made of. The work schedule (#144) is always
  /// written: null means "no schedule was set".
  static Map<String, dynamic> buildFullBackup({
    required List<dynamic> templates,
    required List<dynamic> notes,
    required List<dynamic> history,
    required List<dynamic> standardTasks,
    required List<dynamic> trackedActivities,
    WorkSchedule? workSchedule,
  }) =>
      {
        'templates': templates,
        'notes': notes,
        'history': history,
        'standardTasks': standardTasks,
        'trackedActivities': trackedActivities,
        'workSchedule': workSchedule?.toJson(),
      };

  /// What a full backup says about the work schedule: [apply] is false when the
  /// file has nothing usable (a backup made before the schedule existed, or a
  /// damaged entry), so the current schedule must stay as it is. With [apply]
  /// true, [schedule] is the one to set, or null if no schedule was set when
  /// the backup was made.
  static ({bool apply, WorkSchedule? schedule}) workScheduleOfBackup(
    Map<String, dynamic> data,
  ) {
    if (!data.containsKey('workSchedule')) return (apply: false, schedule: null);
    final raw = data['workSchedule'];
    if (raw == null) return (apply: true, schedule: null);
    final schedule = raw is Map ? WorkSchedule.tryParse(jsonEncode(raw)) : null;
    if (schedule == null) return (apply: false, schedule: null);
    return (apply: true, schedule: schedule);
  }

  static Future<bool> exportAll({
    required Box templatesBox,
    required Box notesBox,
    required Box historyBox,
    required Box standardTasksBox,
    required Box trackedActivitiesBox,
    WorkSchedule? workSchedule,
    String? suggestedName,
  }) async {
    final all = buildFullBackup(
      templates: templatesBox.values.map((e) => (e as dynamic).toJson()).toList(),
      notes: notesBox.values.map((e) => (e as dynamic).toJson()).toList(),
      history: historyBox.values.map((e) => (e as dynamic).toJson()).toList(),
      standardTasks:
          standardTasksBox.values.map((e) => (e as dynamic).toJson()).toList(),
      trackedActivities: trackedActivitiesBox.values
          .map((e) => (e as dynamic).toJson())
          .toList(),
      workSchedule: workSchedule,
    );
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
    Future<void> Function(WorkSchedule? schedule)? applyWorkSchedule,
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

    final scheduleInBackup = workScheduleOfBackup(data);

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
    if (scheduleInBackup.apply) {
      await applyWorkSchedule?.call(scheduleInBackup.schedule);
    }

    return true;
  }
}