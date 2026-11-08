import 'package:flutter/material.dart';
import '../../utils/day_part.dart';

/// Bottom bar of the day screen: type a name and press Enter to add a task,
/// or open the standard-task picker with the "+" button (#109).
/// A selected start time is optional and is reused for consecutive quick adds.
class QuickAddBar extends StatefulWidget {
  final void Function(String name, int? startMinutes) onAdd;
  final ValueChanged<int?> onOpenPicker;
  final Future<TimeOfDay?> Function(BuildContext, TimeOfDay)? timePicker;

  const QuickAddBar({
    super.key,
    required this.onAdd,
    required this.onOpenPicker,
    this.timePicker,
  });

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends State<QuickAddBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int? _startMinutes;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final initial = _startMinutes ?? 9 * 60;
    final initialTime = TimeOfDay(hour: initial ~/ 60, minute: initial % 60);
    final picked = widget.timePicker != null
        ? await widget.timePicker!(context, initialTime)
        : await showTimePicker(
            context: context,
            initialTime: initialTime,
            builder: (ctx, child) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            ),
          );
    if (picked == null || !mounted) return;
    setState(() => _startMinutes = picked.hour * 60 + picked.minute);
  }

  void _submit([String? _]) {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    widget.onAdd(name, _startMinutes);
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
                onPressed: () => widget.onOpenPicker(_startMinutes),
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
                icon: Icon(
                  _startMinutes == null ? Icons.schedule : Icons.schedule_send,
                ),
                tooltip: _startMinutes == null
                    ? 'Назначить время'
                    : 'Время: ${formatMinutes(_startMinutes!)} · Изменить',
                onPressed: _pickStartTime,
              ),
              if (_startMinutes != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    formatMinutes(_startMinutes!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (_startMinutes != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Убрать время',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _startMinutes = null),
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
