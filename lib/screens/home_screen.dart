import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/node.dart';
import 'editor_screen.dart';
import 'book_screen.dart';
import '../utils/file_utils.dart';
import '../widgets/book_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Box<Node> templatesBox;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    print('HomeScreen.initState()');
    try {
      templatesBox = Hive.box<Node>('templates');
      print('HomeScreen: templatesBox получен');
    } catch (e) {
      print('❌ Ошибка получения templatesBox: $e');
    }
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

  @override
  Widget build(BuildContext context) {
    print('HomeScreen.build()');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои книги'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addTemplate),
          IconButton(
            icon: const Icon(Icons.upload),
            onPressed: _importTemplate,
            tooltip: 'Импорт из JSON',
          ),
        ],
      ),
      body: Column(
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
                print('ValueListenableBuilder: box.length = ${box.length}');
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
      ),
    );
  }
}
