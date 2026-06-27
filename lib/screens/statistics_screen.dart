import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/activity_calendar.dart';
import 'components/app_drawer_menu.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Статистика')),
      endDrawer: const AppDrawerMenu(),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final books = appState.books;
          final plans = appState.plans;

          if (books.isEmpty && plans.isEmpty) {
            return const Center(child: Text('Нет данных для отображения.'));
          }

          int totalLeaves = 0;
          int completedLeaves = 0;
          final allItems = <Map<String, dynamic>>[];

          for (var book in books) {
            final t = book.totalLeaves;
            final c = book.completedLeaves;
            totalLeaves += t;
            completedLeaves += c;
            allItems.add({
              'name': book.name,
              'total': t,
              'completed': c,
              'category': 'book',
            });
          }

          for (var plan in plans) {
            final t = plan.totalLeaves;
            final c = plan.completedLeaves;
            totalLeaves += t;
            completedLeaves += c;
            allItems.add({
              'name': plan.name,
              'total': t,
              'completed': c,
              'category': 'plan',
            });
          }

          final overallProgress = totalLeaves > 0
              ? completedLeaves / totalLeaves
              : 0.0;

          allItems.sort(
                (a, b) => (b['completed'] / b['total']).compareTo(
              a['completed'] / a['total'],
            ),
          );
          final topItems = allItems.take(5).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const ActivityCalendar(),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Общая статистика',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _StatRow(
                        'Всего книг/планов:',
                        '${books.length + plans.length}',
                      ),
                      _StatRow('Всего задач:', '$totalLeaves'),
                      _StatRow('Выполнено:', '$completedLeaves'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: overallProgress,
                        backgroundColor: Colors.grey[300],
                        color: Colors.blue,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Общий прогресс: ${(overallProgress * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              if (topItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Лидеры прогресса',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...topItems.map((item) {
                  final progress = item['completed'] / item['total'];
                  final category = item['category'] == 'book'
                      ? 'Книга'
                      : 'План';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item['name'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: category == 'Книга'
                                      ? Colors.blue.shade100
                                      : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: category == 'Книга'
                                        ? Colors.blue.shade800
                                        : Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${item['completed']}/${item['total']}'),
                              Text('${(progress * 100).toStringAsFixed(1)}%'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[300],
                            color: Colors.blue,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}