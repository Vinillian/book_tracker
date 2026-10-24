import 'package:flutter/material.dart';

/// Bottom bar of the day screen: type a name and press Enter to add a task,
/// or open the standard-task picker with the "+" button (#109).
class QuickAddBar extends StatefulWidget {
  final ValueChanged<String> onAdd;
  final VoidCallback onOpenPicker;

  const QuickAddBar({
    super.key,
    required this.onAdd,
    required this.onOpenPicker,
  });

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends State<QuickAddBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit([String? _]) {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    widget.onAdd(name);
    _controller.clear();
    // Enter closes the keyboard by default; keep it open to add several tasks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Стандартные задачи',
                onPressed: widget.onOpenPicker,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Добавить задачу',
                    border: InputBorder.none,
                  ),
                  onSubmitted: _submit,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                tooltip: 'Добавить',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
