import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../models/note.dart';
import '../models/history_entry.dart';
import '../models/standard_task.dart';
import '../models/tracked_activity.dart';
import '../providers/app_state.dart';
import '../utils/file_transfer.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  late final AppState _appState;

  // Диапазоны дат для экспорта Plans/History — применяются только к экспорту,
  // независимы друг от друга (см. #92). null = экспортировать всё, без фильтра.
  ExportDateRange? _plansRange;
  ExportDateRange? _historyRange;

  @override
  void initState() {
    super.initState();
    _appState = context.read<AppState>();
  }

  // ========== Действия ==========
  Future<bool> _exportBooks() => FileTransfer.exportCategory(
    box: _appState.templatesBox,
    category: 'book',
    categoryFilter: 'book',
    suggestedName: 'books',
  );
  Future<int> _importBooks() => FileTransfer.importIntoBox(
    box: _appState.templatesBox,
    fromJson: Node.fromJson,
    setCategory: 'book',
  );

  Future<bool> _exportPlans() => FileTransfer.exportCategory(
    box: _appState.templatesBox,
    category: 'planner',
    categoryFilter: 'planner',
    dateRange: _plansRange,
    dateExtractor: FileTransfer.planDateFromNode,
    suggestedName: 'plans',
  );
  Future<int> _importPlans() => FileTransfer.importIntoBox(
    box: _appState.templatesBox,
    fromJson: Node.fromJson,
    setCategory: 'planner',
  );

  Future<bool> _exportTemplates() => FileTransfer.exportCategory(
    box: _appState.templatesBox,
    category: 'template',
    categoryFilter: 'template',
    suggestedName: 'templates',
  );
  Future<int> _importTemplates() => FileTransfer.importIntoBox(
    box: _appState.templatesBox,
    fromJson: Node.fromJson,
    setCategory: 'template',
  );

  // Только inbox-заметки (linkedNodeId == null). Заметки, привязанные к дням
  // планов, сюда сознательно не входят — см. дизайн-решение по #93.
  Future<bool> _exportNotes() => FileTransfer.exportCategory(
    box: _appState.notesBox,
    category: 'note',
    filter: (n) => n.linkedNodeId == null,
    suggestedName: 'notes',
  );
  Future<int> _importNotes() => FileTransfer.importIntoBox(
    box: _appState.notesBox,
    fromJson: Note.fromJson,
    filterJson: (json) => json['linkedNodeId'] == null,
  );

  Future<bool> _exportHistory() => FileTransfer.exportCategory(
    box: _appState.historyBox,
    category: 'history',
    dateRange: _historyRange,
    dateExtractor: (h) => h.date,
    suggestedName: 'history',
  );
  Future<int> _importHistory() => FileTransfer.importIntoBox(
    box: _appState.historyBox,
    fromJson: HistoryEntry.fromJson,
  );

  // Стандартные задачи
  Future<bool> _exportStandardTasks() => FileTransfer.exportCategory(
    box: _appState.standardTasksBox,
    category: 'standardTask',
    suggestedName: 'standard_tasks',
  );
  Future<int> _importStandardTasks() => FileTransfer.importIntoBox(
    box: _appState.standardTasksBox,
    fromJson: StandardTask.fromJson,
  );

  // Отслеживаемые задачи
  Future<bool> _exportTrackedActivities() => FileTransfer.exportCategory(
    box: _appState.trackedActivitiesBox,
    category: 'trackedActivity',
    suggestedName: 'tracked_activities',
  );
  Future<int> _importTrackedActivities() => FileTransfer.importIntoBox(
    box: _appState.trackedActivitiesBox,
    fromJson: TrackedActivity.fromJson,
  );

  Future<bool> _exportAll() => FileTransfer.exportAll(
    templatesBox: _appState.templatesBox,
    notesBox: _appState.notesBox,
    historyBox: _appState.historyBox,
    standardTasksBox: _appState.standardTasksBox,
    trackedActivitiesBox: _appState.trackedActivitiesBox,
  );
  Future<bool> _importAll() => FileTransfer.importAll(
    templatesBox: _appState.templatesBox,
    notesBox: _appState.notesBox,
    historyBox: _appState.historyBox,
    standardTasksBox: _appState.standardTasksBox,
    trackedActivitiesBox: _appState.trackedActivitiesBox,
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
    if (ok) {
      _appState.notify();
      _showSnackBar('Данные восстановлены');
    } else {
      _showSnackBar('Ошибка восстановления');
    }
  }

  // ========== Date range (export-only, для Plans/History) ==========

  ExportDateRange _presetRange(int days) {
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    final start = end.subtract(Duration(days: days - 1));
    return ExportDateRange(start: start, end: end);
  }

  Future<void> _pickCustomRange({
    required ExportDateRange? current,
    required ValueChanged<ExportDateRange?> onChanged,
  }) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: current != null
          ? DateTimeRange(start: current.start, end: current.end)
          : null,
    );
    if (picked != null) {
      onChanged(ExportDateRange(start: picked.start, end: picked.end));
    }
  }

  Widget _buildRangeSelector({
    required ExportDateRange? current,
    required ValueChanged<ExportDateRange?> onChanged,
  }) {
    String label(ExportDateRange r) =>
        '${DateFormat('dd.MM.yyyy').format(r.start)} – ${DateFormat('dd.MM.yyyy').format(r.end)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ActionChip(
            label: const Text('2 недели'),
            onPressed: () => onChanged(_presetRange(14)),
          ),
          ActionChip(
            label: const Text('Месяц'),
            onPressed: () => onChanged(_presetRange(30)),
          ),
          ActionChip(
            label: const Text('Квартал'),
            onPressed: () => onChanged(_presetRange(90)),
          ),
          ActionChip(
            label: const Text('Свой диапазон'),
            onPressed: () =>
                _pickCustomRange(current: current, onChanged: onChanged),
          ),
          if (current != null)
            Chip(
              label: Text(label(current)),
              onDeleted: () => onChanged(null),
            )
          else
            const Text(
              'Без фильтра — экспортируется всё',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
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
          _buildRangeSelector(
            current: _plansRange,
            onChanged: (r) => setState(() => _plansRange = r),
          ),
          _buildTile(
            'Экспорт планов',
                () => _runExport(
              _exportPlans,
              'Планы экспортированы',
              'Нет планов для экспорта в выбранном диапазоне или отменено',
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
          _sectionHeader('Заметки (inbox)'),
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
          _buildRangeSelector(
            current: _historyRange,
            onChanged: (r) => setState(() => _historyRange = r),
          ),
          _buildTile(
            'Экспорт истории',
                () => _runExport(
              _exportHistory,
              'История экспортирована',
              'Нет истории для экспорта в выбранном диапазоне или отменено',
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
          _sectionHeader('Стандартные задачи'),
          _buildTile(
            'Экспорт стандартных задач',
                () => _runExport(
              _exportStandardTasks,
              'Стандартные задачи экспортированы',
              'Нет задач для экспорта или отменено',
            ),
          ),
          _buildTile(
            'Импорт стандартных задач',
                () => _runImport(
              _importStandardTasks,
              'Импортировано стандартных задач',
              'Файл не выбран или нет данных',
            ),
          ),
          _sectionHeader('Отслеживаемые задачи'),
          _buildTile(
            'Экспорт отслеживаемых задач',
                () => _runExport(
              _exportTrackedActivities,
              'Отслеживаемые задачи экспортированы',
              'Нет задач для экспорта или отменено',
            ),
          ),
          _buildTile(
            'Импорт отслеживаемых задач',
                () => _runImport(
              _importTrackedActivities,
              'Импортировано отслеживаемых задач',
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