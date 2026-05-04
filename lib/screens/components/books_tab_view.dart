import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/node.dart';
import '../../services/service_locator.dart';
import '../editor_screen.dart';
import '../book_screen.dart';
import '../../widgets/book_card.dart';

class BooksTabView extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const BooksTabView({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final nodeService = ServiceLocator.instance.nodeService;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SearchBar(
            hintText: 'Поиск книг...',
            leading: const Icon(Icons.search),
            onChanged: onSearchChanged,
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: nodeService.box.listenable(),
            builder: (context, Box<Node> box, _) {
              final books = nodeService.books;

              if (books.isEmpty) {
                return const Center(
                  child: Text('Нет книг. Нажмите "+" в шапке, чтобы создать.'),
                );
              }

              final filtered = searchQuery.isEmpty
                  ? books
                  : books
                        .where(
                          (b) => b.name.toLowerCase().contains(
                            searchQuery.toLowerCase(),
                          ),
                        )
                        .toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('Ничего не найдено'));
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final book = filtered[index];
                  final key = nodeService.getKey(book);

                  return BookCard(
                    book: book,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookScreen(
                            node: book,
                            onNodeUpdated: () => nodeService.update(key, book),
                          ),
                        ),
                      );
                    },
                    onEdit: () => _editBook(context, key, book),
                    onDelete: () => _deleteBook(context, key),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _editBook(BuildContext context, dynamic key, Node book) async {
    final nodeService = ServiceLocator.instance.nodeService;
    final updated = await Navigator.push<Node>(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(node: book.deepCopy())),
    );
    if (updated != null && context.mounted) {
      nodeService.update(key, updated);
    }
  }

  void _deleteBook(BuildContext context, dynamic key) {
    ServiceLocator.instance.nodeService.delete(key);
  }
}
