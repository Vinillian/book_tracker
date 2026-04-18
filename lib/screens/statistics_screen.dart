import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/node.dart';
import '../widgets/activity_calendar.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final templatesBox = Hive.box<Node>('templates');

    return Scaffold(
      appBar: AppBar(title: const Text('Статистика')),
      body: ValueListenableBuilder(
        valueListenable: templatesBox.listenable(),
        builder: (context, Box<Node> box, _) {
          final nodes = box.values
              .where((n) => n.category == 'book' || n.category == 'planner')
              .toList();

          if (nodes.isEmpty) {
            return const Center(
              child: Text('Нет данных для отображения статистики.'),
            );
          }

          int totalBooks = nodes.where((n) => n.category == 'book').length;
          int totalPlans = nodes.where((n) => n.category == 'planner').length;
          int totalLeaves = 0;
          int completedLeaves = 0;

          final List<Map<String, dynamic>> itemsStats = [];

          for (var node in nodes) {
            final total = node.totalLeaves;
            final completed = node.completedLeaves;
            totalLeaves += total;
            completedLeaves += completed;

            itemsStats.add({
              'name': node.name,
              'total': total,
              'completed': completed,
              'category': node.category,
            });
          }

          final overallProgress = totalLeaves > 0
              ? completedLeaves / totalLeaves
              : 0.0;

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
                      _buildStatRow('Книг:', '$totalBooks'),
                      _buildStatRow('Планов (дней):', '$totalPlans'),
                      _buildStatRow('Всего задач:', '$totalLeaves'),
                      _buildStatRow('Выполнено:', '$completedLeaves'),
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
              const SizedBox(height: 16),
              const Text(
                'Прогресс по элементам',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...itemsStats.map((stat) {
                final progress = stat['total'] > 0
                    ? stat['completed'] / stat['total']
                    : 0.0;
                final category = stat['category'] == 'book' ? 'Книга' : 'План';
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
                                stat['name'],
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
                                color: stat['category'] == 'book'
                                    ? Colors.blue.shade100
                                    : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: stat['category'] == 'book'
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
                            Text('${stat['completed']}/${stat['total']}'),
                            Text('${(progress * 100).toStringAsFixed(1)}%'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[300],
                          color: stat['category'] == 'book'
                              ? Colors.blue
                              : Colors.green,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
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
