import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/app_state.dart';
import '../utils/delete_with_undo.dart';
import '../utils/template_target.dart';
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
  // Filter of the management list: null = all, otherwise a template target.
  String? _filter;

  /// Asks what a template is for. 'any' means "no target"; null = cancelled.
  Future<String?> _pickTarget({required bool allowAny}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Для чего шаблон?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, templateTargetDay),
            child: const Text('Для дня'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, templateTargetBook),
            child: const Text('Для книги'),
          ),
          if (allowAny)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'any'),
              child: const Text('Любой (и для дня, и для книги)'),
            ),
        ],
      ),
    );
  }

  Future<void> _createTemplate(AppState appState) async {
    final target = await _pickTarget(allowAny: false);
    if (target == null || !mounted) return;
    appState.addNode(
      Node(
        name: 'Новый шаблон',
        children: [],
        category: 'template',
        templateTarget: target,
      ),
    );
  }

  Future<void> _changeTarget(AppState appState, Node template) async {
    final target = await _pickTarget(allowAny: true);
    if (target == null || !mounted) return;
    template.templateTarget = target == 'any' ? null : target;
    appState.updateNode(appState.getKeyForNode(template), template);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final wanted = widget.selectionMode
        ? templateTargetForCategory(widget.filterCategory)
        : _filter;
    final templates = [
      for (final t in appState.templates)
        if (templateMatchesTarget(t, wanted)) t,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Шаблоны'),
        actions: widget.selectionMode
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _createTemplate(appState),
                  tooltip: 'Новый шаблон',
                ),
              ],
      ),
      body: Column(
        children: [
          if (!widget.selectionMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final f in <String?>[
                    null,
                    templateTargetDay,
                    templateTargetBook,
                  ])
                    ChoiceChip(
                      label: Text(
                        f == null
                            ? 'Все'
                            : (f == templateTargetDay ? 'Дни' : 'Книги'),
                      ),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ],
              ),
            ),
          Expanded(
            child: templates.isEmpty
                ? Center(
                    child: Text(
                      widget.selectionMode
                          ? 'Нет подходящих шаблонов. Создайте их в меню «Шаблоны».'
                          : 'Нет шаблонов. Нажмите + для создания.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                final key = appState.getKeyForNode(template);

                return Dismissible(
                  key: ValueKey(template.id),
                  // No swipe-to-delete while a template is being picked.
                  direction: widget.selectionMode
                      ? DismissDirection.none
                      : DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => deleteNodeWithUndo(context, template),
                  child: Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ListTile(
                    title: Text(template.name),
                    subtitle: Text(
                      '${templateTargetLabel(template.templateTarget)} · Элементов: ${template.totalLeaves}',
                    ),
                    trailing: widget.selectionMode
                        ? const Icon(Icons.arrow_forward)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.label_outline),
                                tooltip: 'Для чего шаблон',
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    _changeTarget(appState, template),
                              ),
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
                                onPressed: () => deleteNodeWithUndo(context, template),
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
