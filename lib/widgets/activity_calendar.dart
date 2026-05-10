import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../models/history_entry.dart';

class ActivityCalendar extends StatefulWidget {
  const ActivityCalendar({super.key});

  @override
  State<ActivityCalendar> createState() => _ActivityCalendarState();
}

class _ActivityCalendarState extends State<ActivityCalendar> {
  static const double _cellSize = 12;
  static const double _cellMargin = 2;

  final ScrollController _scrollController = ScrollController();

  bool _initialScrollDone = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Map<DateTime, int> _buildActivityMap(Box<HistoryEntry> historyBox) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(now.year - 1, now.month, now.day);

    final map = <DateTime, int>{};

    for (var d = start; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
      map[DateTime(d.year, d.month, d.day)] = 0;
    }

    for (final entry in historyBox.values) {
      final date = DateTime(entry.date.year, entry.date.month, entry.date.day);

      if (map.containsKey(date)) {
        map.update(date, (v) => v + 1);
      }
    }

    return map;
  }

  List<List<DateTime>> _weeks(Map<DateTime, int> activity) {
    final dates = activity.keys.toList()..sort();

    if (dates.isEmpty) {
      return [];
    }

    final first = dates.first;
    final start = first.subtract(Duration(days: first.weekday % 7));

    final last = dates.last;
    final end = last.add(Duration(days: 6 - (last.weekday % 7)));

    final weeks = <List<DateTime>>[];

    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 7))) {
      weeks.add(
        List.generate(
          7,
          (i) => DateTime(
            d.add(Duration(days: i)).year,
            d.add(Duration(days: i)).month,
            d.add(Duration(days: i)).day,
          ),
        ),
      );
    }

    return weeks;
  }

  List<HistoryEntry> _getEntriesForDay(Box<HistoryEntry> box, DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    return box.values
        .where((e) => e.date.isAfter(start) && e.date.isBefore(end))
        .toList();
  }

  Color _colorForCount(int count) {
    if (count == 0) {
      return const Color(0xFFEBEDF0);
    }

    if (count < 3) {
      return const Color(0xFF9BE9A8);
    }

    if (count < 6) {
      return const Color(0xFF40C463);
    }

    if (count < 10) {
      return const Color(0xFF30A14E);
    }

    return const Color(0xFF216E39);
  }

  Widget _buildCell(Color color) {
    return Container(
      width: _cellSize,
      height: _cellSize,
      margin: const EdgeInsets.symmetric(horizontal: _cellMargin),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
    );
  }

  void _scrollToEndOnce() {
    if (_initialScrollDone) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);

        _initialScrollDone = true;
      }
    });
  }

  void _showDayDetails(
    BuildContext context,
    DateTime day,
    Box<HistoryEntry> historyBox,
  ) {
    initializeDateFormatting('ru');

    final entries = _getEntriesForDay(historyBox, day);
    final dateStr = DateFormat('dd MMMM yyyy', 'ru').format(day);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[850],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Всего действий: ${entries.length}',
                style: const TextStyle(color: Colors.white70),
              ),
              const Divider(color: Colors.white24),
              entries.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'Нет действий за этот день',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    )
                  : Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];

                          String action;
                          IconData icon;

                          if (entry.stepType == 'single') {
                            action = entry.completed == true
                                ? 'Выполнено'
                                : 'Снято';

                            icon = entry.completed == true
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked;
                          } else {
                            action = 'Шагов: ${entry.completedSteps}';
                            icon = Icons.list;
                          }

                          return ListTile(
                            leading: Icon(
                              icon,
                              color: Colors.white70,
                              size: 20,
                            ),
                            title: Text(
                              entry.nodeName,
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: Text(
                              action,
                              style: const TextStyle(color: Colors.white54),
                            ),
                            dense: true,
                          );
                        },
                      ),
                    ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Закрыть',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyBox = Hive.box<HistoryEntry>('history');

    return ValueListenableBuilder(
      valueListenable: historyBox.listenable(),
      builder: (context, Box<HistoryEntry> box, _) {
        final activity = _buildActivityMap(box);
        final weeks = _weeks(activity);

        if (weeks.isEmpty) {
          return const Center(
            child: Text(
              'Нет данных для отображения',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        _scrollToEndOnce();

        return Card(
          color: Colors.grey[850],
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const SizedBox(height: 4),
                const Text(
                  'Календарь активности',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: weeks.map((week) {
                        return Column(
                          children: week.map((day) {
                            final count = activity[day] ?? 0;

                            return GestureDetector(
                              onTap: () => _showDayDetails(context, day, box),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 1,
                                ),
                                child: _buildCell(_colorForCount(count)),
                              ),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
