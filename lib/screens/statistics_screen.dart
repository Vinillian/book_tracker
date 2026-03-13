import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/node.dart';

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
          if (box.isEmpty) {
            return const Center(
              child: Text('Нет книг для отображения статистики.'),
            );
          }

          int totalBooks = box.length;
          int totalLeaves = 0;
          int completedLeaves = 0;

          final List<Map<String, dynamic>> booksStats = [];

          for (var key in box.keys) {
            final book = box.get(key)!;
            final bookTotal = book.totalLeaves;
            final bookCompleted = book.completedLeaves;
            totalLeaves += bookTotal;
            completedLeaves += bookCompleted;

            booksStats.add({
              'name': book.name,
              'total': bookTotal,
              'completed': bookCompleted,
            });
          }

          final overallProgress = totalLeaves > 0
              ? completedLeaves / totalLeaves
              : 0.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                'Прогресс по книгам',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...booksStats.map((stat) {
                final progress = stat['total'] > 0
                    ? stat['completed'] / stat['total']
                    : 0.0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat['name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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
                          color: Colors.green,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                );
              }), // удалён .toList()
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
