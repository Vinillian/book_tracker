import 'package:flutter/material.dart';
import '../../models/history_entry.dart';
import '../../utils/format_minutes.dart';

/// Read-only list of what was done on a day (History entries for that date).
class DayDoneSection extends StatelessWidget {
  final List<HistoryEntry> entries;

  const DayDoneSection({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          'Выполнено (${entries.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final entry in entries)
                  ListTile(
                    dense: true,
                    leading: entry.stepType == 'single'
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : entry.stepType == 'duration'
                            ? const Icon(Icons.timer, color: Colors.blue)
                            : const Icon(Icons.list, color: Colors.blue),
                    title: Text(entry.nodeName),
                    trailing: entry.stepType == 'stepByStep'
                        ? Text('Шагов: ${entry.completedSteps}')
                        : entry.stepType == 'duration'
                            ? Text(formatDuration(entry.minutes ?? 0))
                            : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
