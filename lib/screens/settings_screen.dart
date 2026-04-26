import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/node.dart';
import '../utils/file_utils.dart';
import '../utils/history_service.dart';
import '../utils/backup_service.dart'; // <-- новый импорт

class SettingsScreen extends StatelessWidget {
  final String currentThemeMode;
  final Function(String) onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  Future<void> _exportCategory(BuildContext context, String category) async {
    final box = Hive.box<Node>('templates');
    final items = box.values.where((n) => n.category == category).toList();

    if (items.isEmpty) {
      _showSnackBar(context, 'Нет элементов для экспорта');
      return;
    }

    try {
      await FileUtils.exportAllTemplates(items);
      if (context.mounted) {
        _showSnackBar(context, 'Экспорт выполнен успешно');
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Ошибка экспорта: $e', isError: true);
      }
    }
  }

  Future<void> _importAsCategory(BuildContext context, String category) async {
    try {
      if (category == 'planner') {
        // Для планов используем новый метод, поддерживающий JSON-массивы
        final count = await BackupService.importPlansFromJson(
          clearExisting: false,
        );
        if (context.mounted) {
          _showSnackBar(context, 'Импортировано планов: $count');
        }
      } else {
        final imported = await FileUtils.importTemplate();
        if (imported != null) {
          imported.category = category;
          final box = Hive.box<Node>('templates');
          await box.add(imported);
          if (context.mounted) {
            _showSnackBar(context, 'Импортировано как "${imported.name}"');
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Ошибка импорта: $e', isError: true);
      }
    }
  }

  Future<void> _clearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистка истории'),
        content: const Text(
          'Вы уверены, что хотите удалить ВСЮ историю прогресса? Это действие необратимо.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await HistoryService.clearHistory();
      if (context.mounted) {
        _showSnackBar(context, 'История очищена');
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Ошибка: $e', isError: true);
      }
    }
  }

  Future<void> _resetAllProgress(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сброс прогресса'),
        content: const Text(
          'Обнулить прогресс ВСЕХ задач (книг, планов, шаблонов)? '
          'Отметки выполнения будут сняты.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сбросить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final box = Hive.box<Node>('templates');
    for (final key in box.keys) {
      final node = box.get(key);
      if (node != null) {
        _resetNodeProgress(node);
        await box.put(key, node);
      }
    }

    if (context.mounted) {
      _showSnackBar(context, 'Прогресс сброшен');
    }
  }

  void _resetNodeProgress(Node node) {
    if (node.children.isEmpty) {
      node.completed = false;
      node.completedSteps = 0;
    } else {
      for (final child in node.children) {
        _resetNodeProgress(child);
      }
    }
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Тема оформления',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          _buildThemeTile('Системная', 'system'),
          _buildThemeTile('Светлая', 'light'),
          _buildThemeTile('Тёмная', 'dark'),

          const Divider(height: 32, thickness: 1),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Управление данными',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),

          // Экспорт
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('Экспортировать все книги'),
            onTap: () => _exportCategory(context, 'book'),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Экспортировать все планы'),
            onTap: () => _exportCategory(context, 'planner'),
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Экспортировать все шаблоны'),
            onTap: () => _exportCategory(context, 'template'),
          ),

          const Divider(),
          // Импорт
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Импортировать как книгу'),
            onTap: () => _importAsCategory(context, 'book'),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Импортировать как план'),
            onTap: () => _importAsCategory(context, 'planner'),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Импортировать как шаблон'),
            onTap: () => _importAsCategory(context, 'template'),
          ),

          const Divider(),
          // Очистка и сброс
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Очистить историю прогресса'),
            subtitle: const Text('Удалить все записи активности'),
            onTap: () => _clearHistory(context),
          ),
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.orange),
            title: const Text('Сбросить весь прогресс'),
            subtitle: const Text('Обнулить отметки выполнения'),
            onTap: () => _resetAllProgress(context),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildThemeTile(String title, String value) {
    return ListTile(
      title: Text(title),
      leading: Radio<String>(
        value: value,
        groupValue: currentThemeMode,
        onChanged: (v) {
          if (v != null) onThemeChanged(v);
        },
      ),
      onTap: () => onThemeChanged(value),
    );
  }
}
