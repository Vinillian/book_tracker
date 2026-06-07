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
  int _monthsToShow = 3;

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
        final start = DateTime(end.year, end.month - _monthsToShow, end.day);
        final days = heatmapService.getDateRange(start, end);

        if (!_initialScrollDone) {
          _scrollToToday();
        }

        if (trackedActivities.isEmpty) {
          return Scaffold(
            key: _scaffoldKey, // добавляем ключ для открытия меню
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
            endDrawer: AppDrawerMenu(  // добавляем endDrawer
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
                  value: _monthsToShow,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 мес')),
                    DropdownMenuItem(value: 3, child: Text('3 мес')),
                    DropdownMenuItem(value: 6, child: Text('6 мес')),
                    DropdownMenuItem(value: 12, child: Text('1 год')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _monthsToShow = value;
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
            trackVisibility: true,
            interactive: true,
            thickness: 12,
            radius: const Radius.circular(6),
            child: SingleChildScrollView(
              controller: _verticalController,
              child: RawScrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                thickness: 12,
                radius: const Radius.circular(6),
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 180,
                        child: Column(
                          children: [
                            Container(
                              height: 78,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: const Text(
                                'Задача',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            ...trackedActivities.map(
                                  (activity) => Container(
                                height: 42,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  activity.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              SizedBox(
                                height: 28,
                                child: Row(
                                  children: [
                                    for (int i = 0; i < days.length; i++)
                                      if (i == 0 || days[i].month != days[i - 1].month)
                                        Container(
                                          width: (42 *
                                              days
                                                  .skip(i)
                                                  .takeWhile((d) => d.month == days[i].month)
                                                  .length)
                                              .toDouble(),
                                          height: 28,
                                          alignment: Alignment.centerLeft,
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: Text(
                                            _monthName(days[i].month),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 50,
                                child: Row(
                                  children: days.map((date) {
                                    final isToday = date.year == today.year &&
                                        date.month == today.month &&
                                        date.day == today.day;
                                    return Container(
                                      width: 42,
                                      height: 50,
                                      decoration: isToday
                                          ? BoxDecoration(
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.primary,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      )
                                          : null,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '${date.day}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            _weekDayName(date.weekday),
                                            style: const TextStyle(fontSize: 9),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                          ...trackedActivities.map(
                                (activity) {
                              return Row(
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
                                      width: 40,
                                      height: 40,
                                      margin: const EdgeInsets.all(1),
                                      decoration: BoxDecoration(
                                        color: intensity == 0
                                            ? Colors.grey.shade200
                                            : color.withValues(
                                          alpha: (0.25 + intensity * 0.15).clamp(0.25, 1.0),
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        border: isToday
                                            ? Border.all(
                                          color: Theme.of(context).colorScheme.primary,
                                          width: 2,
                                        )
                                            : null,
                                      ),
                                      child: intensity > 0
                                          ? Center(
                                        child: Text(
                                          intensity.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                          : null,
                                    );
                                  },
                                ).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}