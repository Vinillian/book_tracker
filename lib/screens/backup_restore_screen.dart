import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/node.dart';
import '../models/note.dart';
import '../models/history_entry.dart';
import '../utils/file_transfer.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  late final Box<Node> templatesBox;
  late final Box<Note> notesBox;
  late final Box<HistoryEntry> historyBox;

  @override
  void initState() {
    super.initState();
    templatesBox = Hive.box<Node>('templates');
    notesBox = Hive.box<Note>('notes');
    historyBox = Hive.box<HistoryEntry>('history');
  }

  // ========== Действия ==========
  Future<bool> _exportBooks() => FileTransfer.exportBox(
    box: templatesBox,
    categoryFilter: 'book',
    suggestedName: 'books',
  );
  Future<int> _importBooks() => FileTransfer.importIntoBox(
    box: templatesBox,
    fromJson: Node.fromJson,
    setCategory: 'book',
  );
  Future<bool> _exportPlans() => FileTransfer.exportBox(
    box: templatesBox,
    categoryFilter: 'planner',
    suggestedName: 'plans',
  );
  Future<int> _importPlans() => FileTransfer.importIntoBox(
    box: templatesBox,
    fromJson: Node.fromJson,
    setCategory: 'planner',
  );
  Future<bool> _exportTemplates() => FileTransfer.exportBox(
    box: templatesBox,
    categoryFilter: 'template',
    suggestedName: 'templates',
  );
  Future<int> _importTemplates() => FileTransfer.importIntoBox(
    box: templatesBox,
    fromJson: Node.fromJson,
    setCategory: 'template',
  );
  Future<bool> _exportNotes() =>
      FileTransfer.exportBox(box: notesBox, suggestedName: 'notes');
  Future<int> _importNotes() =>
      FileTransfer.importIntoBox(box: notesBox, fromJson: Note.fromJson);
  Future<bool> _exportHistory() =>
      FileTransfer.exportBox(box: historyBox, suggestedName: 'history');
  Future<int> _importHistory() => FileTransfer.importIntoBox(
    box: historyBox,
    fromJson: HistoryEntry.fromJson,
  );
  Future<bool> _exportAll() => FileTransfer.exportAll(
    templatesBox: templatesBox,
    notesBox: notesBox,
    historyBox: historyBox,
  );
  Future<bool> _importAll() => FileTransfer.importAll(
    templatesBox: templatesBox,
    notesBox: notesBox,
    historyBox: historyBox,
  );

  // ========== Вспомогательные методы для SnackBar ==========
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _runExport(
    Future<bool> Function() action,
    String successMsg,
    String emptyMsg,
  ) async {
    bool ok = false;
    try {
      ok = await action();
    } catch (e) {
      _showSnackBar('Ошибка экспорта: $e');
      return;
    }
    _showSnackBar(ok ? successMsg : emptyMsg);
  }

  Future<void> _runImport(
    Future<int> Function() action,
    String successMsg,
    String emptyMsg,
  ) async {
    int result;
    try {
      result = await action();
    } catch (e) {
      _showSnackBar('Ошибка: $e');
      return;
    }
    if (result == -1) {
      _showSnackBar('Ошибка чтения файла. Проверьте формат JSON.');
    } else if (result == 0) {
      _showSnackBar(emptyMsg);
    } else {
      _showSnackBar('$successMsg: $result');
    }
  }

  Future<void> _runRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Восстановление'),
        content: const Text('Все текущие данные будут заменены. Продолжить?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _importAll();
    _showSnackBar(ok ? 'Данные восстановлены' : 'Ошибка восстановления');
  }

  // ========== UI ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Импорт и экспорт')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Книги'),
          _buildTile(
            'Экспорт книг',
            () => _runExport(
              _exportBooks,
              'Книги экспортированы',
              'Нет книг для экспорта или отменено',
            ),
          ),
          _buildTile(
            'Импорт книг',
            () => _runImport(
              _importBooks,
              'Импортировано книг',
              'Файл не выбран или нет данных',
            ),
          ),
          _sectionHeader('Планы'),
          _buildTile(
            'Экспорт планов',
            () => _runExport(
              _exportPlans,
              'Планы экспортированы',
              'Нет планов для экспорта или отменено',
            ),
          ),
          _buildTile(
            'Импорт планов',
            () => _runImport(
              _importPlans,
              'Импортировано планов',
              'Файл не выбран или нет данных',
            ),
          ),
          _sectionHeader('Шаблоны'),
          _buildTile(
            'Экспорт шаблонов',
            () => _runExport(
              _exportTemplates,
              'Шаблоны экспортированы',
              'Нет шаблонов для экспорта или отменено',
            ),
          ),
          _buildTile(
            'Импорт шаблонов',
            () => _runImport(
              _importTemplates,
              'Импортировано шаблонов',
              'Файл не выбран или нет данных',
            ),
          ),
          _sectionHeader('Заметки'),
          _buildTile(
            'Экспорт заметок',
            () => _runExport(
              _exportNotes,
              'Заметки экспортированы',
              'Нет заметок для экспорта или отменено',
            ),
          ),
          _buildTile(
            'Импорт заметок',
            () => _runImport(
              _importNotes,
              'Импортировано заметок',
              'Файл не выбран или нет данных',
            ),
          ),
          _sectionHeader('История'),
          _buildTile(
            'Экспорт истории',
            () => _runExport(
              _exportHistory,
              'История экспортирована',
              'Нет истории для экспорта или отменено',
            ),
          ),
          _buildTile(
            'Импорт истории',
            () => _runImport(
              _importHistory,
              'Импортировано записей истории',
              'Файл не выбран или нет данных',
            ),
          ),
          const Divider(height: 32),
          _sectionHeader('Полный бэкап'),
          _buildTile(
            'Экспорт всего',
            () => _runExport(
              _exportAll,
              'Полный бэкап сохранён',
              'Ошибка сохранения',
            ),
          ),
          _buildTile('Восстановление из бэкапа', _runRestore),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTile(String title, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward),
        onTap: onTap,
      ),
    );
  }
}
