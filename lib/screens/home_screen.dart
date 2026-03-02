import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/node.dart';
import '../models/settings.dart';
import 'editor_screen.dart';
import 'book_screen.dart';
import 'settings_screen.dart';
import '../utils/file_utils.dart';

class HomeScreen extends StatefulWidget {
  final Function(String) onThemeChanged;

  const HomeScreen({super.key, required this.onThemeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Box<Node> templatesBox;
  late Box<AppSettings> settingsBox;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    templatesBox = Hive.box<Node>('templates');
    settingsBox = Hive.box<AppSettings>('settings');
  }

  void _addTemplate() {
    final newTemplate = Node(name: 'Новая книга', children: []);
    templatesBox.add(newTemplate);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Импорт отменён')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои книги'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final settings = settingsBox.get('appSettings');
              final currentMode = settings?.themeMode ?? 'system';

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    currentThemeMode: currentMode,
                    onThemeChanged: widget.onThemeChanged,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addTemplate,
          ),
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
                if (box.isEmpty) {
                  return const Center(
                    child: Text('Нет книг. Нажмите + для создания.'),
                  );
                }

                // Получаем все записи (ключ + значение)
                final entries = box.toMap().entries.toList();
                // Фильтруем по названию
                final filteredEntries = _searchQuery.isEmpty
                    ? entries
                    : entries.where((entry) =>
                    entry.value.name.toLowerCase().contains(_searchQuery.toLowerCase()))
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
                    final completed = template.completedLeaves;
                    final total = template.totalLeaves;
                    final progress = total > 0 ? completed / total : 0.0;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text(template.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey[300],
                              color: Colors.blue,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 4),
                            Text('$completed/$total'),
                          ],
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
                                templatesBox.put(key, updated);
                              }
                            } else if (value == 'delete') {
                              templatesBox.delete(key);
                            } else if (value == 'export') {
                              try {
                                await FileUtils.exportTemplate(template);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Книга экспортирована')),
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
                                  templatesBox.put(key, template);
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
          ),
        ],
      ),
    );
  }
}