import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tracked_activity.dart';
import '../providers/app_state.dart';
import '../services/heatmap_service.dart';
import 'tracked_activities_screen.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  late HeatmapService _heatmapService;
  Map<DateTime, Map<String, int>> _data = {};
  List<DateTime> _days = [];
  List<TrackedActivity> _trackedActivities = [];

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _heatmapService = HeatmapService(appState.historyBox, appState.trackedActivitiesBox);
    _loadData();
  }

  void _loadData() {
    final appState = Provider.of<AppState>(context, listen: false);
    setState(() {
      _data = _heatmapService.getIntensityData();
      _trackedActivities = appState.trackedActivities.where((t) => t.isActive).toList();
      final end = DateTime.now();
      final start = DateTime(end.year - 1, end.month, end.day);
      _days = _heatmapService.getDateRange(start, end);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_trackedActivities.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Тепловая карта активности'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TrackedActivitiesScreen()),
                ).then((_) => _loadData());
              },
            ),
          ],
        ),
        body: const Center(child: Text('Нет отслеживаемых задач. Добавьте их в настройках.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тепловая карта активности'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrackedActivitiesScreen()),
              ).then((_) => _loadData());
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовки задач
            Row(
              children: [
                const SizedBox(width: 60, child: Text('Дата', style: TextStyle(fontWeight: FontWeight.bold))),
                ..._trackedActivities.map((t) => SizedBox(
                  width: 50,
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Text(
                      t.name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )),
              ],
            ),
            // Сетка данных
            ..._days.map((date) {
              final dayData = _data[date] ?? {};
              return Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text('${date.day}.${date.month}.${date.year}'),
                  ),
                  ..._trackedActivities.map((t) {
                    final intensity = dayData[t.nodeId] ?? 0;
                    final color = Color(t.colorValue);
                    final alpha = (intensity * 25.5).clamp(0, 255).toInt();
                    return Container(
                      width: 50,
                      height: 50,
                      margin: const EdgeInsets.all(2),
                      color: color.withAlpha(alpha),
                      child: Center(
                        child: Text(
                          intensity > 0 ? '$intensity' : '',
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}