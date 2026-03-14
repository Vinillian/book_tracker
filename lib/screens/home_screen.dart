import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/node.dart';
import 'editor_screen.dart';
import 'book_screen.dart';
import '../utils/file_utils.dart';
import '../widgets/book_card.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(String) onThemeChanged;
  final String currentThemeMode;

  const HomeScreen({
    super.key,
    required this.onThemeChanged,
    required this.currentThemeMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late Box<Node> templatesBox;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    templatesBox = Hive.box<Node>('templates');
  }

  void _addTemplate() {
    final newTemplate = Node(name: 'Новая книга', children: []);
    templatesBox.add(newTemplate);
  }

  Future<void> _importTemplate() async {
    try {
      final imported = await FileUtils.importTemplate();
      if (imported != null) {
        templatesBox.add(imported);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Книга "${imported.name}" импортирована')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка импорта: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportAllTemplates() async {
    final templates = templatesBox.values.toList();
    if (templates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Нет книг для экспорта')));
      return;
    }
    try {
      await FileUtils.exportAllTemplates(templates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Все книги экспортированы')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editTemplate(dynamic key, Node template) async {
    final updated = await Navigator.push<Node>(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(node: template.deepCopy()),
      ),
    );
    if (updated != null && mounted) {
      templatesBox.put(key, updated);
    }
  }

  Future<void> _exportTemplate(Node template) async {
    try {
      await FileUtils.exportTemplate(template);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Книга "${template.name}" экспортирована')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteTemplate(dynamic key) {
    templatesBox.delete(key);
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          currentThemeMode: widget.currentThemeMode,
          onThemeChanged: (mode) {
            widget.onThemeChanged(mode);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: _getTitle(), actions: _getActions()),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildBooksTab(),
          const CalendarScreen(),
          const StatisticsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Книги'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Календарь',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Статистика',
          ),
        ],
      ),
    );
  }

  Widget _getTitle() {
    switch (_selectedIndex) {
      case 0:
        return const Text('Мои книги');
      case 1:
        return const Text('Календарь');
      case 2:
        return const Text('Статистика');
      default:
        return const Text('Book Planner');
    }
  }

  List<Widget>? _getActions() {
    if (_selectedIndex == 0) {
      return [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _openSettings,
          tooltip: 'Настройки',
        ),
        IconButton(
          icon: const Icon(Icons.download),
          onPressed: _importTemplate,
          tooltip: 'Импорт из JSON',
        ),
        IconButton(
          icon: const Icon(Icons.upload),
          onPressed: _exportAllTemplates,
          tooltip: 'Экспорт всех книг',
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _addTemplate,
          tooltip: 'Новая книга',
        ),
      ];
    }
    return null; // для других вкладок actions не нужны
  }

  Widget _buildBooksTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SearchBar(
            hintText: 'Поиск книг...',
            leading: const Icon(Icons.search),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: templatesBox.listenable(),
            builder: (context, Box<Node> box, _) {
              if (box.isEmpty) {
                return const Center(
                  child: Text('Нет книг. Нажмите + для создания.'),
                );
              }

              final entries = box.toMap().entries.toList();
              final filteredEntries = _searchQuery.isEmpty
                  ? entries
                  : entries
                        .where(
                          (entry) => entry.value.name.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ),
                        )
                        .toList();

              if (filteredEntries.isEmpty) {
                return const Center(
                  child: Text('Нет книг, соответствующих запросу.'),
                );
              }

              return ListView.builder(
                itemCount: filteredEntries.length,
                itemBuilder: (context, index) {
                  final entry = filteredEntries[index];
                  final key = entry.key;
                  final template = entry.value;

                  return BookCard(
                    book: template,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookScreen(
                            node: template,
                            onNodeUpdated: () {
                              templatesBox.put(key, template);
                            },
                          ),
                        ),
                      );
                    },
                    onEdit: () => _editTemplate(key, template),
                    onDelete: () => _deleteTemplate(key),
                    onExport: () => _exportTemplate(template),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
