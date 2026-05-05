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

class CalendarScreen extends StatefulWidget {
  final String currentThemeMode;
  final Function(String) onThemeChanged;

  const CalendarScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

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

  String _getBookName(String bookId) {
    final appState = context.read<AppState>();
    final book = appState.getNodeById(bookId);
    return book?.name ?? 'Книга удалена';
  }

  Node? _existingPlanForDay(DateTime day) {
    final dateStr = DateFormat('dd.MM.yyyy').format(day);
    final appState = context.read<AppState>();
    return appState.plans.cast<Node?>().firstWhere(
      (n) => n!.name == dateStr,
      orElse: () => null,
    );
  }

  Future<void> _createOrOpenPlan(DateTime day) async {
    final appState = context.read<AppState>();
    final dateStr = DateFormat('dd.MM.yyyy').format(day);
    final existing = _existingPlanForDay(day);

    if (existing != null) {
      final key = appState.getKeyForNode(existing);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookScreen(
            node: existing,
            onNodeUpdated: () => appState.updateNode(key, existing),
          ),
        ),
      );
    } else {
      final newPlan = Node(
        name: dateStr,
        children: [],
        category: 'planner',
        stepType: 'folder',
      );
      appState.addNode(newPlan);
      appState.createNoteForDay(newPlan.id);

      if (mounted) {
        final key = appState.getKeyForNode(newPlan);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookScreen(
              node: newPlan,
              onNodeUpdated: () => appState.updateNode(key, newPlan),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingPlan = _selectedDay != null
        ? _existingPlanForDay(_selectedDay!)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Календарь прогресса')),
      endDrawer: AppDrawerMenu(
        currentThemeMode: widget.currentThemeMode,
        onThemeChanged: widget.onThemeChanged,
      ),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _selectedDay == null
                  ? null
                  : () => _createOrOpenPlan(_selectedDay!),
              icon: Icon(existingPlan != null ? Icons.edit : Icons.add),
              label: Text(
                existingPlan != null ? 'Открыть план' : 'Создать план',
              ),
            ),
          ),
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
        final bookName = _getBookName(entry.bookId);
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
            subtitle: Text(bookName),
            trailing: entry.stepType == 'stepByStep'
                ? Text('Шагов: ${entry.completedSteps}')
                : null,
          ),
        );
      },
    );
  }
}
