import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/node.dart';
import 'editor_screen.dart';
import 'book_screen.dart';
import '../utils/file_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Box<Node> templatesBox;

  @override
  void initState() {
    super.initState();
    templatesBox = Hive.box<Node>('templates');
  }

  void _addTemplate() {
    final newTemplate = Node(name: 'Новая книга', children: []);
    templatesBox.add(newTemplate);
  }

  void _deleteTemplate(int index) {
    templatesBox.deleteAt(index);
  }

  Future<void> _importTemplate() async {
    try {
      final imported = await FileUtils.importTemplate();
      if (!mounted) return;
      if (imported != null) {
        templatesBox.add(imported);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Книга "${imported.name}" импортирована')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Импорт отменён')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: ValueListenableBuilder(
        valueListenable: templatesBox.listenable(),
        builder: (context, Box<Node> box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Text('Нет книг. Нажмите + для создания.'),
            );
          }
          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (context, index) {
              final template = box.getAt(index)!;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(template.name),
                  subtitle: Text(
                    '${template.completedLeaves}/${template.totalLeaves}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditorScreen(node: template),
                          ),
                        );
                        if (!mounted) return;
                        if (updated != null) {
                          templatesBox.putAt(index, updated);
                        }
                      } else if (value == 'delete') {
                        _deleteTemplate(index);
                      } else if (value == 'export') {
                        try {
                          await FileUtils.exportTemplate(template);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Книга экспортирована'),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ошибка экспорта: $e')),
                          );
                        }
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Редактировать'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Удалить'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'export',
                          child: Text('Экспорт'),
                        ),
                      ];
                    },
                    icon: const Icon(Icons.more_vert),
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookScreen(
                          node: template,
                          onNodeUpdated: () {
                            templatesBox.putAt(index, template);
                          },
                        ),
                      ),
                    );
                    if (!mounted) return;
                    setState(() {});
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
