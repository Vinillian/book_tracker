import 'package:flutter/material.dart';

/// Asked when a day already exists for the chosen date: add the tasks to it?
/// Returns true only if the user confirmed.
Future<bool> confirmAppendToExistingDay(
  BuildContext context,
  String dateStr,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('День $dateStr уже существует'),
      content: const Text(
        'Добавить задачи в этот день? Уже имеющиеся задачи не изменятся.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Добавить'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
