import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/history_entry.dart';

class ActivityCalendar extends StatelessWidget {
  const ActivityCalendar({super.key});

  static const double _cellSize = 12;
  static const double _cellMargin = 2;
  static const double _columnWidth = _cellSize + _cellMargin * 2;

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
        map[date] = (map[date] ?? 0) + 1; // исправлено
      }
    }
    return map;
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
    if (count == 0) return const Color(0xFFEBEDF0);
    if (count < 3) return const Color(0xFF9BE9A8);
    if (count < 6) return const Color(0xFF40C463);
    if (count < 10) return const Color(0xFF30A14E);
    return const Color(0xFF216E39);
  }

  List<List<DateTime>> _weeks(Map<DateTime, int> activity) {
    final dates = activity.keys.toList()..sort();
    if (dates.isEmpty) return [];

    var cur = dates.first;
    while (cur.weekday != DateTime.monday) {
      cur = cur.subtract(const Duration(days: 1));
    }

    final last = dates.last;
    final weeks = <List<DateTime>>[];

    while (!cur.isAfter(last)) {
      final week = <DateTime>[];
      for (int i = 0; i < 7; i++) {
        week.add(cur);
        cur = cur.add(const Duration(days: 1));
      }
      weeks.add(week);
    }
    return weeks;
  }

  Widget _monthHeaders(List<List<DateTime>> weeks) {
    if (weeks.isEmpty) return const SizedBox.shrink();
    final headers = <Widget>[];
    String? currentMonth;
    double width = 0;

    for (final week in weeks) {
      final first = week.first;
      final label = (first.year <= 1) ? null : DateFormat.MMM().format(first);
      if (label == null) {
        width += _columnWidth;
        continue;
      }
      if (label != currentMonth) {
        if (currentMonth != null) {
          headers.add(
            SizedBox(
              width: width,
              child: Center(
                child: Text(
                  currentMonth, // <-- убрали !
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ),
            ),
          );
        }
        currentMonth = label;
        width = _columnWidth;
      } else {
        width += _columnWidth;
      }
    }
    if (currentMonth != null) {
      headers.add(
        SizedBox(
          width: width,
          child: Center(
            child: Text(
              currentMonth,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ),
        ),
      );
    }
    return Row(children: headers);
  }

  double _calculateMaxScrollExtent(List<List<DateTime>> weeks) {
    return (weeks.length * _columnWidth) - 300;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildTodayStats(Map<DateTime, int> activity) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayCount = activity[today] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Сегодня: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          Text(
            '$todayCount действий',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _colorForCount(todayCount),
            ),
          ),
          if (todayCount > 0) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.check_circle,
              color: _colorForCount(todayCount),
              size: 16,
            ),
          ],
        ],
      ),
    );
  }

  Widget _legendBox(Color color) => Container(
    width: 12,
    height: 12,
    margin: const EdgeInsets.symmetric(horizontal: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: const Color(0x33FFFFFF)),
    ),
  );

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
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Нет действий за этот день',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              else
                Flexible(
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
                        leading: Icon(icon, color: Colors.white70, size: 20),
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

        final maxScrollExtent = _calculateMaxScrollExtent(weeks);
        final scrollController = ScrollController(
          initialScrollOffset: maxScrollExtent,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.jumpTo(maxScrollExtent);
          }
        });

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
                SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 18),
                          for (final day in [
                            'Пн',
                            '',
                            'Ср',
                            '',
                            'Пт',
                            '',
                            'Вс',
                          ])
                            SizedBox(
                              height: _cellSize + _cellMargin * 2,
                              width: 24,
                              child: Center(
                                child: Text(
                                  day,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _monthHeaders(weeks),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: weeks.map((week) {
                              return SizedBox(
                                width: _columnWidth,
                                child: Column(
                                  children: List.generate(7, (i) {
                                    if (i >= week.length)
                                      return const SizedBox();
                                    final date = week[i];
                                    final count =
                                        activity[DateTime(
                                          date.year,
                                          date.month,
                                          date.day,
                                        )] ??
                                        0;
                                    final color = _colorForCount(count);
                                    final isToday = _isToday(date);

                                    return GestureDetector(
                                      onTap: () =>
                                          _showDayDetails(context, date, box),
                                      child: Container(
                                        width: _cellSize,
                                        height: _cellSize,
                                        margin: const EdgeInsets.all(
                                          _cellMargin,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                          border: Border.all(
                                            color: isToday
                                                ? Colors.blue.withValues(
                                                    alpha: 0.8,
                                                  )
                                                : const Color(0x33FFFFFF),
                                            width: isToday ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Tooltip(
                                          message:
                                              '${DateFormat('dd MMM yyyy').format(date)}\n$count действий${isToday ? ' (сегодня)' : ''}',
                                          child: const SizedBox.expand(),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildTodayStats(activity),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Меньше',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    _legendBox(const Color(0xFFEBEDF0)),
                    const SizedBox(width: 4),
                    _legendBox(const Color(0xFF9BE9A8)),
                    const SizedBox(width: 4),
                    _legendBox(const Color(0xFF40C463)),
                    const SizedBox(width: 4),
                    _legendBox(const Color(0xFF30A14E)),
                    const SizedBox(width: 4),
                    _legendBox(const Color(0xFF216E39)),
                    const SizedBox(width: 8),
                    const Text(
                      'Больше',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
