import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/nested_category.dart';

void main() {
  Node brokenBook() {
    final sub = Node.leaf('Подзадача', category: 'book');
    final task = Node(
      name: 'Глава',
      category: 'book',
      stepType: 'single',
      children: [sub],
    );
    final folder = Node(
      name: 'Часть',
      category: 'book',
      stepType: 'folder',
      children: [task],
    );
    return Node(
      name: 'Книга',
      category: 'book',
      stepType: 'folder',
      children: [folder, Node.leaf('Приложение', category: 'book')],
    );
  }

  test('clears book on every nested node and keeps the root', () {
    final book = brokenBook();
    expect(clearNestedBookCategory(book), 4);
    expect(book.category, 'book');
    final folder = book.children[0];
    final task = folder.children.single;
    expect(folder.category, isNull);
    expect(task.category, isNull);
    expect(task.children.single.category, isNull);
    expect(book.children[1].category, isNull);
  });

  test('nested tasks have their own progress again', () {
    final book = brokenBook();
    clearNestedBookCategory(book);
    final task = book.children[0].children.single;
    expect(task.hasOwnProgress, isTrue);
  });

  test('is idempotent and leaves a healthy book alone', () {
    final book = brokenBook();
    clearNestedBookCategory(book);
    expect(clearNestedBookCategory(book), 0);
    final healthy = Node(
      name: 'Книга',
      category: 'book',
      stepType: 'folder',
      children: [Node.leaf('a'), Node.leaf('b')],
    );
    expect(clearNestedBookCategory(healthy), 0);
  });

  test('other categories on nested nodes are not touched', () {
    final root = Node(
      name: 'Книга',
      category: 'book',
      stepType: 'folder',
      children: [Node.leaf('a', category: 'planner')],
    );
    expect(clearNestedBookCategory(root), 0);
    expect(root.children.single.category, 'planner');
  });
}
