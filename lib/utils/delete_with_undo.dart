import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/app_state.dart';

/// Удаляет книгу или план с «Отменить».
///
/// Узел сразу пропадает из списков, но заметки и History стираются только
/// когда snackbar закрылся без нажатия «Отменить» (см. #110, #84).
void deleteNodeWithUndo(BuildContext context, Node node) {
  final appState = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);

  // Закрывает предыдущий snackbar: его удаление фиксируется.
  messenger.clearSnackBars();

  appState.hideNodeForDeletion(node);

  var undone = false;
  messenger
      .showSnackBar(
        SnackBar(
          content: Text(
            'Удалено: ${node.name.isEmpty ? "[Без названия]" : node.name}',
          ),
          duration: const Duration(seconds: 6),
          // SnackBar с action по умолчанию не закрывается сам (persist = true),
          // а удаление фиксируется только по закрытию.
          persist: false,
          action: SnackBarAction(
            label: 'Отменить',
            onPressed: () {
              undone = true;
              appState.restoreNode(node);
            },
          ),
        ),
      )
      .closed
      .then((_) {
        if (!undone) appState.commitNodeDeletion(node);
      });
}
