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
  static const double _columnWidth = _cellSize + _cellMargin * 2;

  final ScrollController _scrollController = ScrollController();
  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();

    initializeDateFormatting('ru');
  }

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
    if (count < 3) return const Color(0xFF9BE9A8);
    if (count < 6) return const Color(0xFF40C463);
    if (count < 10) return const Color(0xFF30A14E);

    return const Color(0xFF216E39);
  }

  Widget _monthHeaders(List<List<DateTime>> weeks) {
    if (weeks.isEmpty) {
      return const SizedBox.shrink();
    }

    final headers = <Widget>[];

    String? currentMonth;
    double width = 0;

    final monthFormat = DateFormat.MMM('ru');

    double textWidth(String text) => text.length * 7.0;

    for (final week in weeks) {
      final first = week.first;
      final label = monthFormat.format(first);

      if (label != currentMonth) {
        if (currentMonth != null) {
          if (width >= textWidth(currentMonth)) {
            headers.add(
              SizedBox(
                width: width,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    currentMonth,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ),
              ),
            );
          } else {
            headers.add(SizedBox(width: width));
          }
        }

        currentMonth = label;
        width = _columnWidth;
      } else {
        width += _columnWidth;
      }
    }

    if (currentMonth != null) {
      if (width >= textWidth(currentMonth)) {
        headers.add(
          SizedBox(
            width: width,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                currentMonth,
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ),
          ),
        );
      } else {
        headers.add(SizedBox(width: width));
      }
    }

    return Row(children: headers);
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
        ],
      ),
    );
  }

  Widget _legendBox(Color color) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
    );
  }

  void _scrollToEndOnce() {
    if (_initialScrollDone) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialScrollDone) return;

      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        _initialScrollDone = true;
      }
    });
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
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Column(
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
                                final date = week[i];
                                final count =
                                    activity[DateTime(
                                      date.year,
                                      date.month,
                                      date.day,
                                    )] ??
                                    0;

                                return Container(
                                  width: _cellSize,
                                  height: _cellSize,
                                  margin: const EdgeInsets.all(_cellMargin),
                                  decoration: BoxDecoration(
                                    color: _colorForCount(count),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
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
