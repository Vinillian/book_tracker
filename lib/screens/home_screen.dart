import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/node.dart';
import '../services/service_locator.dart';
import 'template_manager_screen.dart';
import 'components/books_tab_view.dart';
import 'components/planner_tab_view.dart';
import 'components/app_drawer_menu.dart';

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
  String _searchQuery = '';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ---------- Книги ----------
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
              ServiceLocator.instance.nodeService.add(newBook);
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
      final nodeService = ServiceLocator.instance.nodeService;
      // Глубокое копирование со сбросом прогресса и установкой категории 'book'
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
      newBook.name = selected.name;
      nodeService.add(newBook);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Книга "${newBook.name}" создана из шаблона')),
      );
    }
  }

  // ---------- Планы ----------
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
                  _openTemplateManagerForDay(selectedDate);
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
    final nodeService = ServiceLocator.instance.nodeService;
    final dateStr = DateFormat('dd.MM.yyyy').format(date);
    if (nodeService.planExistsForDate(date)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('День "$dateStr" уже существует')));
      return;
    }
    nodeService.addEmptyDay(date);
  }

  void _openTemplateManagerForDay(DateTime date) async {
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
      final nodeService = ServiceLocator.instance.nodeService;
      final dateStr = DateFormat('dd.MM.yyyy').format(date);
      if (nodeService.planExistsForDate(date)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('День "$dateStr" уже существует')),
        );
        return;
      }
      final newDay = nodeService.addDayFromTemplate(selected, date);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('День "$dateStr" создан из шаблона "${selected.name}"'),
        ),
      );
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: _selectedIndex == 0 ? const Text('Книги') : const Text('Планы'),
        actions: _buildAppBarActions(),
      ),
      endDrawer: AppDrawerMenu(
        currentThemeMode: widget.currentThemeMode,
        onThemeChanged: widget.onThemeChanged,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          BooksTabView(
            searchQuery: _searchQuery,
            onSearchChanged: (value) => setState(() => _searchQuery = value),
          ),
          const PlannerTabView(),
        ],
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
      onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
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
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const TemplateManagerScreen(selectionMode: false),
              ),
            );
          },
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
}
