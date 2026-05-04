import 'package:flutter/material.dart';
import '../../models/node.dart';

class ProgressCard extends StatelessWidget {
  final Node node;

  const ProgressCard({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final completed = node.completedLeaves;
    final total = node.totalLeaves;
    final progress = total > 0 ? completed / total : 0.0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Прогресс',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text('$completed/$total', style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              color: Colors.blue,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      ),
    );
  }
}
