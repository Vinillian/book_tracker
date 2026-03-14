import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/history_entry.dart';
import '../models/node.dart';
import '../utils/history_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<HistoryEntry>> _events = {};
  final Box<Node> _templatesBox = Hive.box<Node>('templates');

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
    final book = _templatesBox.values.firstWhere(
      (b) => b.id == bookId,
      orElse: () => Node(name: 'Книга удалена', children: []),
    );
    return book.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Календарь прогресса')),
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
