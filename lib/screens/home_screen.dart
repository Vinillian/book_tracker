import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/node.dart';
import 'editor_screen.dart';
import 'book_screen.dart';
import '../utils/file_utils.dart';
import '../widgets/book_card.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'calendar_screen.dart';
import 'template_manager_screen.dart'; // <-- добавлен импорт

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

  // ========== Книги ==========
  void _addBook() {
    final newBook = Node(name: 'Новая книга', children: [], category: 'book');
    templatesBox.add(newBook);
  }

  Future<void> _importBook() async {
    try {
      final imported = await FileUtils.importTemplate();
      if (imported != null) {
        imported.category ??= 'book';
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

  Future<void> _exportAllBooks() async {
    final books = templatesBox.values
        .where((n) => n.category == 'book')
        .toList();
    if (books.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Нет книг для экспорта')));
      return;
    }
    try {
      await FileUtils.exportAllTemplates(books);
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

  void _deleteBook(dynamic key) {
    templatesBox.delete(key);
  }

  Future<void> _editBook(dynamic key, Node book) async {
    final updated = await Navigator.push<Node>(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(node: book.deepCopy())),
    );
    if (updated != null && mounted) {
      templatesBox.put(key, updated);
    }
  }

  // ========== Планы ==========
  void _openTemplateManager({bool selectionMode = false}) async {
    if (selectionMode) {
      final selected = await Navigator.push<Node>(
        context,
        MaterialPageRoute(
          builder: (_) => const TemplateManagerScreen(selectionMode: true),
        ),
      );
      if (selected != null && mounted) {
        _createDayFromTemplate(selected);
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const TemplateManagerScreen(selectionMode: false),
        ),
      );
    }
  }

  void _showNewDayDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый день'),
        content: const Text('Выберите способ создания:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addEmptyDay();
            },
            child: const Text('Пустой день'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openTemplateManager(selectionMode: true);
            },
            child: const Text('Из шаблона'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  void _addEmptyDay() {
    final today = DateFormat('dd.MM.yyyy').format(DateTime.now());
    final existing = templatesBox.values.firstWhere(
      (n) => n.name == today && n.category == 'planner',
      orElse: () => Node(name: '', children: []),
    );
    if (existing.name.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('День "$today" уже существует')));
      return;
    }
    final newDay = Node(
      name: today,
      children: [],
      category: 'planner',
      stepType: 'folder',
    );
    templatesBox.add(newDay);
  }

  void _createDayFromTemplate(Node template) {
    final today = DateFormat('dd.MM.yyyy').format(DateTime.now());
    final existing = templatesBox.values.firstWhere(
      (n) => n.name == today && n.category == 'planner',
      orElse: () => Node(name: '', children: []),
    );
    if (existing.name.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('День "$today" уже существует')));
      return;
    }

    // Глубокая копия и сброс прогресса
    Node copyAndReset(Node node) {
      final copy = node.deepCopy();
      if (copy.children.isEmpty) {
        copy.completed = false;
        copy.completedSteps = 0;
      } else {
        copy.children = copy.children.map((c) => copyAndReset(c)).toList();
      }
      return copy;
    }

    final newDay = copyAndReset(template);
    newDay.name = today;
    newDay.category = 'planner';

    templatesBox.add(newDay);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('День "$today" создан из шаблона "${template.name}"'),
      ),
    );
  }

  Future<void> _importPlanner() async {
    try {
      final imported = await FileUtils.importTemplate();
      if (imported != null) {
        imported.category ??= 'planner';
        templatesBox.add(imported);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('План "${imported.name}" импортирован')),
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

  Future<void> _editPlannerDay(dynamic key, Node day) async {
    final updated = await Navigator.push<Node>(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(node: day.deepCopy())),
    );
    if (updated != null && mounted) {
      templatesBox.put(key, updated);
    }
  }

  void _deletePlannerDay(dynamic key) {
    templatesBox.delete(key);
  }

  // ========== Общие ==========
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

  void _openCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CalendarScreen()),
    );
  }

  void _openStatistics() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StatisticsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _selectedIndex == 0 ? const Text('Книги') : const Text('Планы'),
        actions: _buildAppBarActions(),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [_buildBooksTab(), _buildPlannerTab()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Книги'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Планы',
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    final common = [
      IconButton(
        icon: const Icon(Icons.calendar_month),
        onPressed: _openCalendar,
        tooltip: 'Календарь',
      ),
      IconButton(
        icon: const Icon(Icons.bar_chart),
        onPressed: _openStatistics,
        tooltip: 'Статистика',
      ),
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: _openSettings,
        tooltip: 'Настройки',
      ),
    ];

    if (_selectedIndex == 0) {
      // Книги
      return [
        ...common,
        IconButton(
          icon: const Icon(Icons.download),
          onPressed: _importBook,
          tooltip: 'Импорт книги',
        ),
        IconButton(
          icon: const Icon(Icons.upload),
          onPressed: _exportAllBooks,
          tooltip: 'Экспорт всех книг',
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _addBook,
          tooltip: 'Новая книга',
        ),
      ];
    } else {
      // Планы
      return [
        ...common,
        IconButton(
          icon: const Icon(Icons.folder),
          onPressed: () => _openTemplateManager(selectionMode: false),
          tooltip: 'Управление шаблонами',
        ),
        IconButton(
          icon: const Icon(Icons.download),
          onPressed: _importPlanner,
          tooltip: 'Импорт плана',
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _showNewDayDialog,
          tooltip: 'Новый день',
        ),
      ];
    }
  }

  Widget _buildBooksTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SearchBar(
            hintText: 'Поиск книг...',
            leading: const Icon(Icons.search),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: templatesBox.listenable(),
            builder: (context, Box<Node> box, _) {
              final books = box.values
                  .where((n) => n.category == 'book')
                  .toList();

              if (books.isEmpty) {
                return const Center(
                  child: Text('Нет книг. Нажмите + для создания.'),
                );
              }

              final filtered = _searchQuery.isEmpty
                  ? books
                  : books
                        .where(
                          (b) => b.name.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ),
                        )
                        .toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('Ничего не найдено'));
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final book = filtered[index];
                  final key = box.keys.firstWhere((k) => box.get(k) == book);

                  return BookCard(
                    book: book,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookScreen(
                            node: book,
                            onNodeUpdated: () => box.put(key, book),
                          ),
                        ),
                      );
                    },
                    onEdit: () => _editBook(key, book),
                    onDelete: () => _deleteBook(key),
                    onExport: () => FileUtils.exportTemplate(book),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlannerTab() {
    return ValueListenableBuilder(
      valueListenable: templatesBox.listenable(),
      builder: (context, Box<Node> box, _) {
        final plans = box.values.where((n) => n.category == 'planner').toList();

        if (plans.isEmpty) {
          return const Center(
            child: Text('Нет планов. Нажмите + для создания дня.'),
          );
        }

        // Сортировка по дате (новые сверху)
        plans.sort((a, b) {
          try {
            final dateA = DateFormat('dd.MM.yyyy').parse(a.name);
            final dateB = DateFormat('dd.MM.yyyy').parse(b.name);
            return dateB.compareTo(dateA);
          } catch (_) {
            return b.name.compareTo(a.name);
          }
        });

        return ListView.builder(
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final plan = plans[index];
            final key = box.keys.firstWhere((k) => box.get(k) == plan);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                title: Text(plan.name),
                subtitle: Text('Задач: ${plan.totalLeaves}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editPlannerDay(key, plan),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deletePlannerDay(key),
                    ),
                  ],
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookScreen(
                        node: plan,
                        onNodeUpdated: () => box.put(key, plan),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
