import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/node.dart';
import '../models/note.dart';
import '../utils/backup_service.dart';
import 'editor_screen.dart';
import 'book_screen.dart';
import '../utils/file_utils.dart';
import '../widgets/book_card.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'calendar_screen.dart';
import 'template_manager_screen.dart';
import 'notes_screen.dart';

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    templatesBox = Hive.box<Node>('templates');
  }

  // ========== Книги ==========
  void _showAddBookDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая книга'),
        content: const Text('Выберите способ создания:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _createEmptyBookWithName();
            },
            child: const Text('Пустая книга'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openTemplateManagerForBook();
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

  void _createEmptyBookWithName() {
    final TextEditingController nameController = TextEditingController(
      text: 'Новая книга',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Название книги'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Название',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final newBook = Node(
                name: name.isEmpty ? 'Новая книга' : name,
                children: [],
                category: 'book',
              );
              templatesBox.add(newBook);
              Navigator.pop(ctx);
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _openTemplateManagerForBook() async {
    final selected = await Navigator.push<Node>(
      context,
      MaterialPageRoute(
        builder: (_) => const TemplateManagerScreen(
          selectionMode: true,
          filterCategory: 'book',
        ),
      ),
    );
    if (selected != null && mounted) {
      Node copyAndReset(Node node) {
        final copy = node.deepCopy();
        copy.category = 'book';
        if (copy.children.isEmpty) {
          copy.completed = false;
          copy.completedSteps = 0;
        } else {
          copy.children = copy.children.map((c) => copyAndReset(c)).toList();
        }
        return copy;
      }

      final newBook = copyAndReset(selected);
      if (newBook.name.isEmpty) newBook.name = selected.name;
      templatesBox.add(newBook);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Книга "${newBook.name}" создана из шаблона')),
      );
    }
  }

  Future<void> _importBook() async {
    try {
      final imported = await FileUtils.importTemplate(addHistory: true);
      if (imported != null) {
        imported.category ??= 'book';
        final existingKey = templatesBox.keys.firstWhere(
          (k) => templatesBox.get(k)?.id == imported.id,
          orElse: () => null,
        );
        if (existingKey != null) {
          await templatesBox.delete(existingKey);
        }
        await templatesBox.add(imported);
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
  void _openTemplateManager({
    bool selectionMode = false,
    DateTime? forDate,
  }) async {
    if (selectionMode) {
      final selected = await Navigator.push<Node>(
        context,
        MaterialPageRoute(
          builder: (_) => const TemplateManagerScreen(
            selectionMode: true,
            filterCategory: 'planner',
          ),
        ),
      );
      if (selected != null && mounted) {
        _createDayFromTemplate(selected, forDate ?? DateTime.now());
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
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Новый день'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    'Дата: ${DateFormat('dd.MM.yyyy').format(selectedDate)}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setStateDialog(() {
                        selectedDate = picked;
                      });
                    }
                  },
                ),
                const Divider(),
                const Text('Выберите способ создания:'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _addEmptyDay(selectedDate);
                },
                child: const Text('Пустой день'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openTemplateManager(
                    selectionMode: true,
                    forDate: selectedDate,
                  );
                },
                child: const Text('Из шаблона'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addEmptyDay(DateTime date) {
    final dateStr = DateFormat('dd.MM.yyyy').format(date);
    final existing = templatesBox.values.firstWhere(
      (n) => n.name == dateStr && n.category == 'planner',
      orElse: () => Node(name: '', children: []),
    );
    if (existing.name.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('День "$dateStr" уже существует')));
      return;
    }
    final newDay = Node(
      name: dateStr,
      children: [],
      category: 'planner',
      stepType: 'folder',
    );
    templatesBox.add(newDay);

    final notesBox = Hive.box<Note>('notes');
    final dayNote = Note(content: '', linkedNodeId: newDay.id);
    notesBox.put(dayNote.id, dayNote);
  }

  void _createDayFromTemplate(Node template, DateTime date) {
    final dateStr = DateFormat('dd.MM.yyyy').format(date);
    final existing = templatesBox.values.firstWhere(
      (n) => n.name == dateStr && n.category == 'planner',
      orElse: () => Node(name: '', children: []),
    );
    if (existing.name.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('День "$dateStr" уже существует')));
      return;
    }

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
    newDay.name = dateStr;
    newDay.category = 'planner';

    templatesBox.add(newDay);

    final notesBox = Hive.box<Note>('notes');
    final dayNote = Note(content: '', linkedNodeId: newDay.id);
    notesBox.put(dayNote.id, dayNote);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('День "$dateStr" создан из шаблона "${template.name}"'),
      ),
    );
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

  void _deletePlannerDay(dynamic key) async {
    final day = templatesBox.get(key);
    if (day != null) {
      final notesBox = Hive.box<Note>('notes');
      final linkedNote = notesBox.values.firstWhere(
        (n) => n.linkedNodeId == day.id,
        orElse: () => Note(content: ''),
      );
      if (linkedNote.id.isNotEmpty) {
        await notesBox.delete(linkedNote.id);
      }
    }
    templatesBox.delete(key);
  }

  // ========== Общие ==========
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

  void _openNotes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotesScreen()),
    );
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Резервное копирование'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('Экспорт полного бэкапа'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final path = await BackupService.exportFullBackup();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          path != null
                              ? 'Бэкап сохранён в $path'
                              : 'Ошибка экспорта',
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Импорт из полного бэкапа'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Восстановление'),
                      content: const Text(
                        'Все текущие данные будут заменены. Продолжить?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Отмена'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Заменить'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  final result = await BackupService.importFullBackup(
                    clearExisting: true,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result != null ? 'Восстановлено' : 'Ошибка импорта',
                        ),
                      ),
                    );
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.book),
                title: const Text('Экспорт книг'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final path = await BackupService.exportBooks();
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          path != null ? 'Книги экспортированы' : 'Нет книг',
                        ),
                      ),
                    );
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Экспорт планов'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final path = await BackupService.exportPlans();
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          path != null ? 'Планы экспортированы' : 'Нет планов',
                        ),
                      ),
                    );
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Экспорт шаблонов'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final path = await BackupService.exportTemplates();
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          path != null
                              ? 'Шаблоны экспортированы'
                              : 'Нет шаблонов',
                        ),
                      ),
                    );
                },
              ),
              ListTile(
                leading: const Icon(Icons.note),
                title: const Text('Экспорт заметок'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final path = await BackupService.exportNotes();
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          path != null
                              ? 'Заметки экспортированы'
                              : 'Нет заметок',
                        ),
                      ),
                    );
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Экспорт истории'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final path = await BackupService.exportHistory();
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          path != null
                              ? 'История экспортирована'
                              : 'Нет истории',
                        ),
                      ),
                    );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: _selectedIndex == 0 ? const Text('Книги') : const Text('Планы'),
        actions: _buildAppBarActions(),
      ),
      endDrawer: _buildDrawer(),
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
        icon: const Icon(Icons.menu),
        onPressed: _openDrawer,
        tooltip: 'Меню',
      ),
    ];

    if (_selectedIndex == 0) {
      return [
        ...common,
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _showAddBookDialog,
          tooltip: 'Новая книга',
        ),
      ];
    } else {
      return [
        ...common,
        IconButton(
          icon: const Icon(Icons.folder),
          onPressed: () => _openTemplateManager(selectionMode: false),
          tooltip: 'Управление шаблонами',
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _showNewDayDialog,
          tooltip: 'Новый день',
        ),
      ];
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.menu_book, size: 40, color: Colors.white),
                SizedBox(height: 8),
                Text(
                  'Book Planner',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Календарь'),
            onTap: () {
              Navigator.pop(context);
              _openCalendar();
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Статистика'),
            onTap: () {
              Navigator.pop(context);
              _openStatistics();
            },
          ),
          ListTile(
            leading: const Icon(Icons.note),
            title: const Text('Inbox'),
            onTap: () {
              Navigator.pop(context);
              _openNotes();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Управление шаблонами'),
            onTap: () {
              Navigator.pop(context);
              _openTemplateManager(selectionMode: false);
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Импорт книги'),
            onTap: () {
              Navigator.pop(context);
              _importBook();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Резервное копирование'),
            onTap: () {
              Navigator.pop(context);
              _showBackupDialog();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Настройки'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    currentThemeMode: widget.currentThemeMode,
                    onThemeChanged: (mode) => widget.onThemeChanged(mode),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
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
                  child: Text('Нет книг. Нажмите "+" в шапке, чтобы создать.'),
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
            child: Text('Нет планов. Нажмите "+" в шапке, чтобы создать день.'),
          );
        }

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
