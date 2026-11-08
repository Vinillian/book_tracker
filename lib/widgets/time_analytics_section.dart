import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/time_analytics_service.dart';
import '../utils/format_minutes.dart';

class TimeAnalyticsSection extends StatefulWidget {
  const TimeAnalyticsSection({super.key});

  @override
  State<TimeAnalyticsSection> createState() => _TimeAnalyticsSectionState();
}

class _TimeAnalyticsSectionState extends State<TimeAnalyticsSection> {
  TimeAnalyticsPeriod _period = TimeAnalyticsPeriod.month;
  Set<String>? _selectedTrackingIds;

  void _selectAll() {
    setState(() => _selectedTrackingIds = null);
  }

  void _toggleActivity(
    String trackingId,
    Set<String> allIds,
    bool selected,
  ) {
    final current = _selectedTrackingIds == null
        ? allIds
        : _selectedTrackingIds!.intersection(allIds);
    final next = Set<String>.from(current);
    if (selected) {
      next.add(trackingId);
    } else {
      next.remove(trackingId);
    }
    setState(() {
      _selectedTrackingIds = next.length == allIds.length ? null : next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final entries = appState.historyBox.values.toList();
    final activities = TimeAnalyticsService.getAvailableActivities(
      entries: entries,
      trackedActivities: appState.trackedActivities,
    );
    final allIds = activities.map((activity) => activity.trackingId).toSet();
    final selectedIds = _selectedTrackingIds == null
        ? allIds
        : _selectedTrackingIds!.intersection(allIds);

    final result = TimeAnalyticsService.calculate(
      entries: entries,
      selectedTrackingIds: selectedIds,
      period: _period,
    );

    final selectedActivities = activities
        .where((activity) => selectedIds.contains(activity.trackingId))
        .toList()
      ..sort((a, b) {
        final aMinutes = result.minutesByActivity[a.trackingId] ?? 0;
        final bMinutes = result.minutesByActivity[b.trackingId] ?? 0;
        return bMinutes.compareTo(aMinutes);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timer_outlined),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Аналитика времени',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Период:'),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<TimeAnalyticsPeriod>(
                    value: _period,
                    isExpanded: true,
                    items: TimeAnalyticsPeriod.values
                        .map(
                          (period) => DropdownMenuItem(
                            value: period,
                            child: Text(period.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _period = value);
                    },
                  ),
                ),
              ],
            ),
            if (activities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Пока нет записанных временных сессий. '
                  'Добавьте время в карточке задачи с учётом времени.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Активности',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _selectAll,
                    child: const Text('Выбрать все'),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: activities.map((activity) {
                  final selected = selectedIds.contains(activity.trackingId);
                  return FilterChip(
                    label: Text(activity.name),
                    selected: selected,
                    onSelected: (value) => _toggleActivity(
                      activity.trackingId,
                      allIds,
                      value,
                    ),
                    avatar: CircleAvatar(
                      radius: 5,
                      backgroundColor: Color(activity.colorValue),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                '${_formatDate(result.startDate)} — '
                '${_formatDate(result.endDate)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _buildSummary(context, result),
              if (!result.isEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Распределение по активностям',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                ...selectedActivities
                    .where((activity) =>
                        (result.minutesByActivity[activity.trackingId] ?? 0) > 0)
                    .map((activity) {
                  final minutes =
                      result.minutesByActivity[activity.trackingId] ?? 0;
                  final maxMinutes = result.minutesByActivity.values.reduce(
                    (a, b) => a > b ? a : b,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                activity.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              formatDuration(minutes),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: minutes / maxMinutes,
                            minHeight: 8,
                            color: Color(activity.colorValue),
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                const Text(
                  'Активность во времени',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _TimeTrendChart(result: result, period: _period),
              ],
              if (result.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'За выбранный период по выбранным активностям времени нет.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, TimeAnalyticsResult result) {
    return Row(
      children: [
        Expanded(
          child: _Metric(
            label: 'Всего времени',
            value: formatDuration(result.totalMinutes),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Metric(
            label: 'В среднем за день',
            value: formatDuration(result.averageMinutesPerDay.round()),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Metric(
            label: 'Дней с активностью',
            value: '${result.daysWithActivity}',
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ChartBucket {
  final DateTime start;
  final DateTime end;
  final int minutes;

  const _ChartBucket(this.start, this.end, this.minutes);
}

class _TimeTrendChart extends StatelessWidget {
  final TimeAnalyticsResult result;
  final TimeAnalyticsPeriod period;

  const _TimeTrendChart({required this.result, required this.period});

  @override
  Widget build(BuildContext context) {
    final buckets = _buildBuckets();
    if (buckets.isEmpty) return const SizedBox.shrink();

    final maxMinutes = buckets.fold<int>(
      0,
      (maximum, bucket) => math.max(maximum, bucket.minutes),
    );
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 126,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: buckets.map((bucket) {
            final barHeight = maxMinutes == 0
                ? 0.0
                : (bucket.minutes / maxMinutes * 82).clamp(2.0, 82.0);
            return SizedBox(
              width: period == TimeAnalyticsPeriod.week ||
                      period == TimeAnalyticsPeriod.month
                  ? 25
                  : 34,
              child: Tooltip(
                message:
                    '${_label(bucket.start)}: ${formatDuration(bucket.minutes)}',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Spacer(),
                    Container(
                      height: barHeight,
                      width: 14,
                      decoration: BoxDecoration(
                        color: bucket.minutes == 0
                            ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                            : primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _label(bucket.start),
                      style: const TextStyle(fontSize: 9),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<_ChartBucket> _buildBuckets() {
    final buckets = <_ChartBucket>[];
    DateTime cursor;
    if (period == TimeAnalyticsPeriod.threeMonths) {
      cursor = result.startDate.subtract(
        Duration(days: result.startDate.weekday - DateTime.monday),
      );
      while (!cursor.isAfter(result.endDate)) {
        final end = cursor.add(const Duration(days: 6));
        buckets.add(_bucket(cursor, end));
        cursor = cursor.add(const Duration(days: 7));
      }
    } else if (period == TimeAnalyticsPeriod.year ||
        period == TimeAnalyticsPeriod.allTime) {
      cursor = DateTime(result.startDate.year, result.startDate.month);
      while (!cursor.isAfter(result.endDate)) {
        final end = DateTime(cursor.year, cursor.month + 1, 0);
        buckets.add(_bucket(cursor, end));
        cursor = DateTime(cursor.year, cursor.month + 1);
      }
    } else {
      cursor = result.startDate;
      while (!cursor.isAfter(result.endDate)) {
        buckets.add(_bucket(cursor, cursor));
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return buckets;
  }

  _ChartBucket _bucket(DateTime start, DateTime end) {
    var minutes = 0;
    for (final entry in result.minutesByDay.entries) {
      if (!entry.key.isBefore(start) && !entry.key.isAfter(end)) {
        minutes += entry.value;
      }
    }
    return _ChartBucket(start, end, minutes);
  }

  String _label(DateTime date) {
    if (period == TimeAnalyticsPeriod.week ||
        period == TimeAnalyticsPeriod.month) {
      return '${date.day}';
    }
    if (period == TimeAnalyticsPeriod.threeMonths) {
      return '${date.day}.${date.month}';
    }
    const months = [
      '',
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    return months[date.month];
  }
}
