import '../models/node.dart';

/// Resets `category` of every nested node of [root] that carries `'book'`
/// (#139). Only roots have a category: before PR #137 a book made from a
/// template got `'book'` on all its nodes, so its tasks lost their own progress
/// and the start-time button. Returns how many nodes were changed; [root]
/// itself is never touched. Safe to run repeatedly.
int clearNestedBookCategory(Node root) {
  var fixed = 0;
  for (final child in root.children) {
    if (child.category == 'book') {
      child.category = null;
      fixed++;
    }
    fixed += clearNestedBookCategory(child);
  }
  return fixed;
}
