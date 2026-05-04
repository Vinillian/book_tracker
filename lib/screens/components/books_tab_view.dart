import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/node.dart';
import '../../providers/app_state.dart';
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
    final appState = context.watch<AppState>();
    final books = appState.books;

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
          child: books.isEmpty
              ? const Center(
                  child: Text('Нет книг. Нажмите "+" в шапке, чтобы создать.'),
                )
              : Builder(
                  builder: (context) {
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
                        final key = appState.getKeyForNode(book);

                        return BookCard(
                          book: book,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookScreen(
                                  node: book,
                                  onNodeUpdated: () =>
                                      appState.updateNode(key, book),
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
    final appState = context.read<AppState>();
    final updated = await Navigator.push<Node>(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(node: book.deepCopy())),
    );
    if (updated != null && context.mounted) {
      appState.updateNode(key, updated);
    }
  }

  void _deleteBook(BuildContext context, dynamic key) {
    context.read<AppState>().deleteNode(key);
  }
}
