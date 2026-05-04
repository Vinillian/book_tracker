import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/app_state.dart';
import 'editor_screen.dart';

class TemplateManagerScreen extends StatefulWidget {
  final bool selectionMode;
  final String? filterCategory;

  const TemplateManagerScreen({
    super.key,
    this.selectionMode = false,
    this.filterCategory,
  });

  @override
  State<TemplateManagerScreen> createState() => _TemplateManagerScreenState();
}

class _TemplateManagerScreenState extends State<TemplateManagerScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final templates = appState.templates;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Шаблоны'),
        actions: widget.selectionMode
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final newTemplate = Node(
                      name: 'Новый шаблон',
                      children: [],
                      category: 'template',
                    );
                    appState.addNode(newTemplate);
                  },
                  tooltip: 'Новый шаблон',
                ),
              ],
      ),
      body: templates.isEmpty
          ? const Center(child: Text('Нет шаблонов. Нажмите + для создания.'))
          : ListView.builder(
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                final key = appState.getKeyForNode(template);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ListTile(
                    title: Text(template.name),
                    subtitle: Text('Элементов: ${template.totalLeaves}'),
                    trailing: widget.selectionMode
                        ? const Icon(Icons.arrow_forward)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () async {
                                  final updated = await Navigator.push<Node>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditorScreen(
                                        node: template.deepCopy(),
                                      ),
                                    ),
                                  );
                                  if (updated != null && mounted) {
                                    updated.category = 'template';
                                    appState.updateNode(key, updated);
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => appState.deleteNode(key),
                              ),
                            ],
                          ),
                    onTap: () {
                      if (widget.selectionMode) {
                        Navigator.pop(context, template);
                      } else {
                        // Редактирование
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
