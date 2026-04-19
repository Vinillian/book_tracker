import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/node.dart';
import '../models/history_entry.dart';
import '../models/note.dart';
import '../models/settings.dart';

class BackupService {
  static Future<String?> _getBackupDirectoryPath() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) return null;
      final storage = await getExternalStorageDirectory();
      final root = Directory(storage!.path.split('Android')[0]);
      final dir = Directory('${root.path}Documents/Book Planner/Backups');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir.path;
    } else {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/Backups');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir.path;
    }
  }

  static Future<String?> _saveFile(String fileName, List<int> bytes) async {
    final dirPath = await _getBackupDirectoryPath();
    if (dirPath == null) return null;
    final file = File('$dirPath/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static List<int> _encodeJsonList(List<dynamic> list) {
    final jsonString = jsonEncode(list);
    return utf8.encode('\uFEFF$jsonString');
  }

  static List<int> _encodeJson(dynamic object) {
    final jsonString = jsonEncode(object);
    return utf8.encode('\uFEFF$jsonString');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Экспорт отдельных категорий
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<String?> exportBooks() async {
    final box = Hive.box<Node>('templates');
    final books = box.values.where((n) => n.category == 'book').toList();
    if (books.isEmpty) return null;
    final jsonList = books.map((b) => b.toJson()).toList();
    final bytes = _encodeJsonList(jsonList);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return _saveFile('books_$timestamp.json', bytes);
  }

  static Future<String?> exportPlans() async {
    final box = Hive.box<Node>('templates');
    final plans = box.values.where((n) => n.category == 'planner').toList();
    if (plans.isEmpty) return null;
    final jsonList = plans.map((p) => p.toJson()).toList();
    final bytes = _encodeJsonList(jsonList);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return _saveFile('plans_$timestamp.json', bytes);
  }

  static Future<String?> exportTemplates() async {
    final box = Hive.box<Node>('templates');
    final templates = box.values
        .where((n) => n.category == 'template')
        .toList();
    if (templates.isEmpty) return null;
    final jsonList = templates.map((t) => t.toJson()).toList();
    final bytes = _encodeJsonList(jsonList);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return _saveFile('templates_$timestamp.json', bytes);
  }

  static Future<String?> exportNotes() async {
    final box = Hive.box<Note>('notes');
    final notes = box.values.toList();
    if (notes.isEmpty) return null;
    final jsonList = notes.map((n) => n.toJson()).toList();
    final bytes = _encodeJsonList(jsonList);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return _saveFile('notes_$timestamp.json', bytes);
  }

  static Future<String?> exportHistory() async {
    final box = Hive.box<HistoryEntry>('history');
    final history = box.values.toList();
    if (history.isEmpty) return null;
    final jsonList = history.map((h) => h.toJson()).toList();
    final bytes = _encodeJsonList(jsonList);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return _saveFile('history_$timestamp.json', bytes);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Полный бэкап (ZIP-архив)
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<String?> exportFullBackup() async {
    final templatesBox = Hive.box<Node>('templates');
    final notesBox = Hive.box<Note>('notes');
    final historyBox = Hive.box<HistoryEntry>('history');
    final settingsBox = Hive.box<AppSettings>('settings');

    final books = templatesBox.values
        .where((n) => n.category == 'book')
        .toList();
    final plans = templatesBox.values
        .where((n) => n.category == 'planner')
        .toList();
    final tmpls = templatesBox.values
        .where((n) => n.category == 'template')
        .toList();
    final notes = notesBox.values.toList();
    final history = historyBox.values.toList();
    final settings = settingsBox.get('appSettings')?.themeMode ?? 'system';

    final archive = Archive();

    archive.addFile(
      ArchiveFile(
        'books.json',
        books.length,
        _encodeJsonList(books.map((b) => b.toJson()).toList()),
      ),
    );
    archive.addFile(
      ArchiveFile(
        'plans.json',
        plans.length,
        _encodeJsonList(plans.map((p) => p.toJson()).toList()),
      ),
    );
    archive.addFile(
      ArchiveFile(
        'templates.json',
        tmpls.length,
        _encodeJsonList(tmpls.map((t) => t.toJson()).toList()),
      ),
    );
    archive.addFile(
      ArchiveFile(
        'notes.json',
        notes.length,
        _encodeJsonList(notes.map((n) => n.toJson()).toList()),
      ),
    );
    archive.addFile(
      ArchiveFile(
        'history.json',
        history.length,
        _encodeJsonList(history.map((h) => h.toJson()).toList()),
      ),
    );
    archive.addFile(
      ArchiveFile(
        'settings.json',
        settings.length,
        _encodeJson({'themeMode': settings}),
      ),
    );

    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) return null;
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return _saveFile('backup_$timestamp.zip', zipData);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Импорт
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<int> importBooks({bool clearExisting = false}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null) return 0;
    final jsonString = await _readString(result);
    final List<dynamic> jsonList = jsonDecode(jsonString);
    final box = Hive.box<Node>('templates');
    if (clearExisting) {
      final keysToDelete = box.keys
          .where((k) => box.get(k)?.category == 'book')
          .toList();
      for (var key in keysToDelete) {
        await box.delete(key);
      }
    }
    int count = 0;
    for (var item in jsonList) {
      final node = Node.fromJson(item);
      node.category = 'book';
      await box.add(node);
      count++;
    }
    return count;
  }

  static Future<int> importPlans({bool clearExisting = false}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null) return 0;
    final jsonString = await _readString(result);
    final List<dynamic> jsonList = jsonDecode(jsonString);
    final box = Hive.box<Node>('templates');
    if (clearExisting) {
      final keysToDelete = box.keys
          .where((k) => box.get(k)?.category == 'planner')
          .toList();
      for (var key in keysToDelete) {
        await box.delete(key);
      }
    }
    int count = 0;
    for (var item in jsonList) {
      final node = Node.fromJson(item);
      node.category = 'planner';
      await box.add(node);
      count++;
    }
    return count;
  }

  static Future<int> importTemplates({bool clearExisting = false}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null) return 0;
    final jsonString = await _readString(result);
    final List<dynamic> jsonList = jsonDecode(jsonString);
    final box = Hive.box<Node>('templates');
    if (clearExisting) {
      final keysToDelete = box.keys
          .where((k) => box.get(k)?.category == 'template')
          .toList();
      for (var key in keysToDelete) {
        await box.delete(key);
      }
    }
    int count = 0;
    for (var item in jsonList) {
      final node = Node.fromJson(item);
      node.category = 'template';
      await box.add(node);
      count++;
    }
    return count;
  }

  static Future<int> importNotes({bool clearExisting = false}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null) return 0;
    final jsonString = await _readString(result);
    final List<dynamic> jsonList = jsonDecode(jsonString);
    final box = Hive.box<Note>('notes');
    if (clearExisting) await box.clear();
    int count = 0;
    for (var item in jsonList) {
      final note = Note.fromJson(item);
      await box.put(note.id, note);
      count++;
    }
    return count;
  }

  static Future<int> importHistory({bool clearExisting = false}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null) return 0;
    final jsonString = await _readString(result);
    final List<dynamic> jsonList = jsonDecode(jsonString);
    final box = Hive.box<HistoryEntry>('history');
    if (clearExisting) await box.clear();
    int count = 0;
    for (var item in jsonList) {
      final entry = HistoryEntry.fromJson(item);
      await box.add(entry);
      count++;
    }
    return count;
  }

  static Future<String?> importFullBackup({bool clearExisting = true}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null) return null;
    final bytes = result.files.first.bytes;
    if (bytes == null) return null;
    final archive = ZipDecoder().decodeBytes(bytes);

    final templatesBox = Hive.box<Node>('templates');
    final notesBox = Hive.box<Note>('notes');
    final historyBox = Hive.box<HistoryEntry>('history');
    final settingsBox = Hive.box<AppSettings>('settings');

    if (clearExisting) {
      await templatesBox.clear();
      await notesBox.clear();
      await historyBox.clear();
    }

    for (var file in archive) {
      final content = utf8.decode(file.content);
      switch (file.name) {
        case 'books.json':
          final List<dynamic> jsonList = jsonDecode(content);
          for (var item in jsonList) {
            final node = Node.fromJson(item);
            node.category = 'book';
            await templatesBox.add(node);
          }
          break;
        case 'plans.json':
          final List<dynamic> jsonList = jsonDecode(content);
          for (var item in jsonList) {
            final node = Node.fromJson(item);
            node.category = 'planner';
            await templatesBox.add(node);
          }
          break;
        case 'templates.json':
          final List<dynamic> jsonList = jsonDecode(content);
          for (var item in jsonList) {
            final node = Node.fromJson(item);
            node.category = 'template';
            await templatesBox.add(node);
          }
          break;
        case 'notes.json':
          final List<dynamic> jsonList = jsonDecode(content);
          for (var item in jsonList) {
            final note = Note.fromJson(item);
            await notesBox.put(note.id, note);
          }
          break;
        case 'history.json':
          final List<dynamic> jsonList = jsonDecode(content);
          for (var item in jsonList) {
            final entry = HistoryEntry.fromJson(item);
            await historyBox.add(entry);
          }
          break;
        case 'settings.json':
          final Map<String, dynamic> map = jsonDecode(content);
          final theme = map['themeMode'] as String? ?? 'system';
          await settingsBox.put('appSettings', AppSettings(themeMode: theme));
          break;
      }
    }
    return 'success';
  }

  static Future<String> _readString(FilePickerResult result) async {
    final bytes = result.files.first.bytes;
    if (bytes != null) {
      return _decodeWithBom(bytes);
    } else {
      final path = result.files.first.path;
      if (path == null) throw Exception('No path');
      final file = File(path);
      final fileBytes = await file.readAsBytes();
      return _decodeWithBom(fileBytes);
    }
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
}
