import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/node.dart';
import '../models/note.dart';
import '../models/history_entry.dart';
import '../utils/file_transfer.dart';
import 'editor_screen.dart';
import 'book_screen.dart';
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

  // ========== Экспорт / Импорт ==========
  Future<void> _exportBooks() async {
    final ok = await FileTransfer.exportBox(
      box: templatesBox,
      categoryFilter: 'book',
      suggestedName: 'books',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Книги экспортированы' : 'Нет книг для экспорта или отменено',
          ),
        ),
      );
    }
  }

  Future<void> _importBooks() async {
    final count = await FileTransfer.importIntoBox(
      box: templatesBox,
      fromJson: Node.fromJson,
      setCategory: 'book',
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Импортировано книг: $count')));
    }
  }

  Future<void> _exportPlans() async {
    final ok = await FileTransfer.exportBox(
      box: templatesBox,
      categoryFilter: 'planner',
      suggestedName: 'plans',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Планы экспортированы'
                : 'Нет планов для экспорта или отменено',
          ),
        ),
      );
    }
  }

  Future<void> _importPlans() async {
    final count = await FileTransfer.importIntoBox(
      box: templatesBox,
      fromJson: Node.fromJson,
      setCategory: 'planner',
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Импортировано планов: $count')));
    }
  }

  Future<void> _exportTemplates() async {
    final ok = await FileTransfer.exportBox(
      box: templatesBox,
      categoryFilter: 'template',
      suggestedName: 'templates',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Шаблоны экспортированы'
                : 'Нет шаблонов для экспорта или отменено',
          ),
        ),
      );
    }
  }

  Future<void> _importTemplates() async {
    final count = await FileTransfer.importIntoBox(
      box: templatesBox,
      fromJson: Node.fromJson,
      setCategory: 'template',
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Импортировано шаблонов: $count')));
    }
  }

  Future<void> _exportNotes() async {
    final box = Hive.box<Note>('notes');
    final ok = await FileTransfer.exportBox(box: box, suggestedName: 'notes');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Заметки экспортированы'
                : 'Нет заметок для экспорта или отменено',
          ),
        ),
      );
    }
  }

  Future<void> _importNotes() async {
    final box = Hive.box<Note>('notes');
    final count = await FileTransfer.importIntoBox(
      box: box,
      fromJson: Note.fromJson,
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Импортировано заметок: $count')));
    }
  }

  Future<void> _exportHistory() async {
    final box = Hive.box<HistoryEntry>('history');
    final ok = await FileTransfer.exportBox(box: box, suggestedName: 'history');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'История экспортирована'
                : 'Нет истории для экспорта или отменено',
          ),
        ),
      );
    }
  }

  Future<void> _importHistory() async {
    final box = Hive.box<HistoryEntry>('history');
    final count = await FileTransfer.importIntoBox(
      box: box,
      fromJson: HistoryEntry.fromJson,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Импортировано записей истории: $count')),
      );
    }
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
    final menuButton = IconButton(
      icon: const Icon(Icons.menu),
      onPressed: _openDrawer,
      tooltip: 'Меню',
    );

    if (_selectedIndex == 0) {
      return [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _showAddBookDialog,
          tooltip: 'Новая книга',
        ),
        menuButton,
      ];
    } else {
      return [
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
        menuButton,
      ];
    }
  }

  Widget _buildDrawer() {
    // Конфигурация пунктов импорта/экспорта для удобства и отсутствия дублирования
    final List<_ExportImportEntry> exportImportEntries = [
      _ExportImportEntry('Экспорт книг', _exportBooks),
      _ExportImportEntry('Импорт книг', _importBooks),
      _ExportImportEntry('Экспорт планов', _exportPlans),
      _ExportImportEntry('Импорт планов', _importPlans),
      _ExportImportEntry('Экспорт шаблонов', _exportTemplates),
      _ExportImportEntry('Импорт шаблонов', _importTemplates),
      _ExportImportEntry('Экспорт заметок', _exportNotes),
      _ExportImportEntry('Импорт заметок', _importNotes),
      _ExportImportEntry('Экспорт истории', _exportHistory),
      _ExportImportEntry('Импорт истории', _importHistory),
    ];

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
          const Divider(),
          ExpansionTile(
            leading: const Icon(Icons.import_export),
            title: const Text('Экспорт / Импорт'),
            children: exportImportEntries.map((entry) {
              return ListTile(
                title: Text(entry.title),
                onTap: () {
                  Navigator.pop(context);
                  entry.action();
                },
              );
            }).toList(),
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

/// Вспомогательный класс для генерации пунктов меню экспорта/импорта
class _ExportImportEntry {
  final String title;
  final VoidCallback action;
  const _ExportImportEntry(this.title, this.action);
}
