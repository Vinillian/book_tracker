import '../models/node.dart';

/// The ids of [root] and of every task below it.
Set<String> collectNodeIds(Node root) {
  final ids = <String>{};
  void walk(Node node) {
    ids.add(node.id);
    for (final child in node.children) {
      walk(child);
    }
  }

  walk(root);
  return ids;
}
