import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/node.dart';
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
  late Box<Node> templatesBox;

  @override
  void initState() {
    super.initState();
    templatesBox = Hive.box<Node>('templates');
  }

  void _addTemplate() {
    final newTemplate = Node(
      name: 'Новый шаблон',
      children: [],
      category: 'template',
    );
    templatesBox.add(newTemplate);
  }

  void _deleteTemplate(dynamic key) {
    templatesBox.delete(key);
  }

  Future<void> _editTemplate(dynamic key, Node template) async {
    final updated = await Navigator.push<Node>(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(node: template.deepCopy()),
      ),
    );
    if (updated != null && mounted) {
      updated.category = 'template';
      templatesBox.put(key, updated);
    }
  }

  void _selectTemplate(Node template) {
    Navigator.pop(context, template);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Шаблоны'),
        actions: widget.selectionMode
            ? null
            : [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addTemplate,
            tooltip: 'Новый шаблон',
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: templatesBox.listenable(),
        builder: (context, Box<Node> box, _) {
          var templates = box.values
              .where((n) => n.category == 'template')
              .toList();

          if (widget.filterCategory != null) {
            templates = templates.where((t) => true).toList();
          }

          if (templates.isEmpty) {
            return const Center(
              child: Text('Нет шаблонов. Нажмите + для создания.'),
            );
          }

          return ListView.builder(
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              final key = box.keys.firstWhere((k) => box.get(k) == template);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                        onPressed: () => _editTemplate(key, template),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteTemplate(key),
                      ),
                    ],
                  ),
                  onTap: () {
                    if (widget.selectionMode) {
                      _selectTemplate(template);
                    } else {
                      _editTemplate(key, template);
                    }
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