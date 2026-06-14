import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/heatmap_service.dart';
import 'tracked_activities_screen.dart';
import 'components/app_drawer_menu.dart';

class HeatmapScreen extends StatefulWidget {
  final String currentThemeMode;
  final Function(String) onThemeChanged;

  const HeatmapScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  bool _initialScrollDone = false;
  int _monthsToShow = 0; // 0 = 2 недели
  bool _isTwoWeeks = true;

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  String _monthName(int month) {
    const months = [
      '', 'Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
      'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек',
    ];
    return months[month];
  }

  String _weekDayName(int weekday) {
    const days = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[weekday];
  }

  void _scrollToToday() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_horizontalController.hasClients) {
        _horizontalController.jumpTo(
          _horizontalController.position.maxScrollExtent,
        );
      }
      _initialScrollDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final heatmapService = HeatmapService(
          appState.historyBox,
          appState.trackedActivitiesBox,
        );

        final data = heatmapService.getIntensityData();
        final trackedActivities = appState.trackedActivities
            .where((t) => t.isActive)
            .toList();

        final today = DateTime.now();
        final end = DateTime(today.year, today.month, today.day);

        DateTime start;
        if (_isTwoWeeks) {
          start = end.subtract(const Duration(days: 14));
        } else {
          start = DateTime(end.year, end.month - _monthsToShow, end.day);
        }

        final days = heatmapService.getDateRange(start, end);

        if (!_initialScrollDone) {
          _scrollToToday();
        }

        const double cellSize = 17.0;
        const double rowHeight = 20.0;
        const double leftColumnWidth = 110; // чуть шире для текста "Задачи"

        if (trackedActivities.isEmpty) {
          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              title: const Text('Тепловая карта активности'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TrackedActivitiesScreen(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                ),
              ],
            ),
            endDrawer: AppDrawerMenu(
              currentThemeMode: widget.currentThemeMode,
              onThemeChanged: widget.onThemeChanged,
            ),
            body: const Center(
              child: Text(
                'Нет отслеживаемых задач.\nДобавьте их в настройках.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: const Text('Тепловая карта активности'),
            actions: [
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _isTwoWeeks ? 0 : _monthsToShow,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('2 недели')),
                    DropdownMenuItem(value: 1, child: Text('1 мес')),
                    DropdownMenuItem(value: 3, child: Text('3 мес')),
                    DropdownMenuItem(value: 6, child: Text('6 мес')),
                    DropdownMenuItem(value: 12, child: Text('1 год')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      if (value == 0) {
                        _isTwoWeeks = true;
                      } else {
                        _isTwoWeeks = false;
                        _monthsToShow = value;
                      }
                      _initialScrollDone = false;
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TrackedActivitiesScreen(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            ],
          ),
          endDrawer: AppDrawerMenu(
            currentThemeMode: widget.currentThemeMode,
            onThemeChanged: widget.onThemeChanged,
          ),
          body: RawScrollbar(
            controller: _verticalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _verticalController,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Левая колонка с названиями задач (фиксированная)
                  SizedBox(
                    width: leftColumnWidth,
                    child: Column(
                      children: [
                        // Заголовок "Задачи" на высоте заголовков месяцев+дней
                        Container(
                          height: 56,
                          alignment: Alignment.center,
                          child: const Text(
                            'Задачи',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        ...trackedActivities.map(
                              (activity) => SizedBox(
                            height: rowHeight,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                activity.name,
                                style: const TextStyle(fontSize: 9),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Правая часть с горизонтальной прокруткой
                  Expanded(
                    child: RawScrollbar(
                      controller: _horizontalController,
                      thumbVisibility: true,
                      interactive: true,
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Строка месяцев
                            SizedBox(
                              height: 28,
                              child: Row(
                                children: days.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final date = entry.value;
                                  final showMonth = index == 0 || date.month != days[index - 1].month;
                                  return Container(
                                    width: cellSize + 2,
                                    height: 28,
                                    alignment: Alignment.centerLeft,
                                    child: showMonth
                                        ? Padding(
                                      padding: const EdgeInsets.only(left: 2),
                                      child: Text(
                                        _monthName(date.month),
                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                        : null,
                                  );
                                }).toList(),
                              ),
                            ),
                            // Строка дней недели и чисел
                            SizedBox(
                              height: 28,
                              child: Row(
                                children: days.map((date) {
                                  final isToday = date.year == today.year &&
                                      date.month == today.month &&
                                      date.day == today.day;
                                  return Container(
                                    width: cellSize + 2,
                                    height: 28,
                                    decoration: isToday
                                        ? BoxDecoration(
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.primary,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    )
                                        : null,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${date.day}',
                                          style: const TextStyle(fontSize: 7),
                                        ),
                                        Text(
                                          _weekDayName(date.weekday),
                                          style: const TextStyle(fontSize: 6),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            // Строки задач
                            ...trackedActivities.map(
                                  (activity) => SizedBox(
                                height: rowHeight,
                                child: Row(
                                  children: days.map(
                                        (date) {
                                      final normalizedDate = DateTime(
                                        date.year,
                                        date.month,
                                        date.day,
                                      );
                                      final intensity = data[normalizedDate]?[activity.nodeId] ?? 0;
                                      final color = Color(activity.colorValue);
                                      final isToday = normalizedDate.year == today.year &&
                                          normalizedDate.month == today.month &&
                                          normalizedDate.day == today.day;

                                      return Container(
                                        width: cellSize,
                                        height: rowHeight - 2,
                                        margin: const EdgeInsets.all(1),
                                        decoration: BoxDecoration(
                                          color: intensity == 0
                                              ? Colors.grey.shade200
                                              : color.withValues(
                                            alpha: (0.25 + intensity * 0.15).clamp(0.25, 1.0),
                                          ),
                                          borderRadius: BorderRadius.circular(2),
                                          border: isToday
                                              ? Border.all(
                                            color: Theme.of(context).colorScheme.primary,
                                            width: 1,
                                          )
                                              : null,
                                        ),
                                        child: intensity > 0
                                            ? Center(
                                          child: Text(
                                            intensity.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 7,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                            : null,
                                      );
                                    },
                                  ).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}