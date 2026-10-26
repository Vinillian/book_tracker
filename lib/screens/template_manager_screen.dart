import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/app_state.dart';
import '../utils/delete_with_undo.dart';
import '../utils/flatten_day_parts.dart';
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

  static String _filterLabel(String? f) {
    switch (f) {
      case null:
        return 'Все';
      case templateTargetDay:
        return 'Дни';
      case templateTargetWork:
        return 'Рабочие';
      case templateTargetOff:
        return 'Выходные';
      default:
        return 'Книги';
    }
  }

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
            onPressed: () => Navigator.pop(ctx, templateTargetWork),
            child: const Text('Для рабочего дня'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, templateTargetOff),
            child: const Text('Для выходного'),
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

  /// Removes the "Утро" / "День" / "Вечер" folders of [template] (#117): their
  /// tasks move to the top level and get a start time, so the day screen groups
  /// them by time of day instead. Asks first; "Отменить" restores the template.
  Future<void> _flattenFolders(AppState appState, Node template) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Убрать папки Утро / День / Вечер?'),
        content: const Text(
          'Задачи из этих папок перейдут на верхний уровень шаблона. '
          'Тем, у кого нет времени начала, будет проставлено время: '
          'утро 08:00, день 13:00, вечер 19:00. '
          'Потом это можно отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Убрать папки'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final key = appState.getKeyForNode(template);
    final before = template.deepCopy();
    appState.updateNode(key, flattenDayPartFolders(template));

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Папки убраны: ${template.name}'),
        duration: const Duration(seconds: 6),
        persist: false,
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () => appState.updateNode(key, before),
        ),
      ),
    );
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
                    templateTargetWork,
                    templateTargetOff,
                    templateTargetBook,
                  ])
                    ChoiceChip(
                      label: Text(_filterLabel(f)),
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
                              if (hasDayPartFolders(template))
                                IconButton(
                                  icon: const Icon(Icons.format_list_bulleted),
                                  tooltip: 'Убрать папки Утро/День/Вечер',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      _flattenFolders(appState, template),
                                ),
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
