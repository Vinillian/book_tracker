import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/history_entry.dart';
import '../models/node.dart';
import '../providers/app_state.dart';
import '../services/history_service.dart';
import 'book_screen.dart';
import 'components/app_drawer_menu.dart';
import 'template_manager_screen.dart';

enum _NewDayChoice { empty, template }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<HistoryEntry>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  void _loadEvents() {
    setState(() {
      _events = HistoryService.getAllEntriesGroupedByDate();
    });
  }

  List<HistoryEntry> _getEventsForDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return _events[normalized] ?? [];
  }

  Node? _existingPlanForDay(DateTime day) {
    final dateStr = DateFormat('dd.MM.yyyy').format(day);
    final appState = context.read<AppState>();
    return appState.plans.cast<Node?>().firstWhere(
          (n) => n!.name == dateStr,
      orElse: () => null,
    );
  }

  Future<void> _openDay(DateTime day) async {
    final existing = _existingPlanForDay(day);
    if (existing != null) {
      await _showDay(existing);
      return;
    }

    final choice = await _askHowToCreate(day);
    if (choice == null || !mounted) return;

    final appState = context.read<AppState>();
    Node? created;
    if (choice == _NewDayChoice.empty) {
      created = appState.addEmptyDay(day);
    } else {
      final template = await Navigator.push<Node>(
        context,
        MaterialPageRoute(
          builder: (_) => const TemplateManagerScreen(
            selectionMode: true,
            filterCategory: 'planner',
          ),
        ),
      );
      if (template == null || !mounted) return;
      created = appState.addDayFromTemplate(template, day);
    }
    if (!mounted) return;
    await _showDay(created);
  }

  Future<_NewDayChoice?> _askHowToCreate(DateTime day) {
    final dateStr = DateFormat('dd.MM.yyyy').format(day);
    return showModalBottomSheet<_NewDayChoice>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Плана на $dateStr нет',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Пустой день'),
              onTap: () => Navigator.pop(ctx, _NewDayChoice.empty),
            ),
            ListTile(
              leading: const Icon(Icons.copy_all),
              title: const Text('Из шаблона'),
              onTap: () => Navigator.pop(ctx, _NewDayChoice.template),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDay(Node plan) async {
    final appState = context.read<AppState>();
    final key = appState.getKeyForNode(plan);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookScreen(
          node: plan,
          onNodeUpdated: () => appState.updateNode(key, plan),
        ),
      ),
    );
    if (mounted) _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Календарь прогресса')),
      endDrawer: const AppDrawerMenu(),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _openDay(selectedDay);
            },
            eventLoader: _getEventsForDay,
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildEventList()),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    if (_selectedDay == null) return const SizedBox.shrink();
    final events = _getEventsForDay(_selectedDay!);
    if (events.isEmpty) {
      return const Center(child: Text('Нет записей за этот день'));
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (ctx, index) {
        final entry = events[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: entry.stepType == 'single'
                ? Icon(
              entry.completed == true
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: entry.completed == true ? Colors.green : Colors.grey,
            )
                : const Icon(Icons.list, color: Colors.blue),
            title: Text(entry.nodeName),
            subtitle: entry.stepType == 'single'
                ? Text(entry.completed == true ? 'Выполнено' : 'Не выполнено')
                : null,
            trailing: entry.stepType == 'stepByStep'
                ? Text('Шагов: ${entry.completedSteps}')
                : null,
          ),
        );
      },
    );
  }
}