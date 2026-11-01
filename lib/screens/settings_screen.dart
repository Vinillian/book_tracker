import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/history_service.dart';
import 'components/app_drawer_menu.dart';
import 'components/app_menu_button.dart';
import 'work_schedule_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static String _dateLabel(DateTime d) => '${d.day}.${d.month}.${d.year}';

  /// Asks for a day and a confirmation, then deletes that day's History.
  /// Everything after an `await` goes through the State's own `context` behind
  /// `mounted`, so leaving the screen meanwhile cannot touch a dead context
  /// (#88).
  Future<void> _deleteHistoryForDay(AppState appState) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (selectedDate == null || !mounted) return;

    final label = _dateLabel(selectedDate);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение'),
        content: Text(
          'Все записи истории за $label будут безвозвратно удалены. Продолжить?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await HistoryService.deleteHistoryForDate(selectedDate);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('История за $label удалена')),
    );
    appState.notify();
  }

  /// Asks for a confirmation, then clears the whole History (#88).
  Future<void> _clearAllHistory(AppState appState) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение'),
        content: const Text(
          'Вся история будет безвозвратно удалена. Продолжить?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await HistoryService.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Вся история удалена')),
    );
    appState.notify();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const AppDrawerMenu(),
      appBar: AppBar(
        title: const Text('Настройки'),
        actions: const [AppMenuButton()],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final currentTheme = appState.themeMode;
          return ListView(
            children: [
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Тема оформления',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              // The group value and the callback live in a RadioGroup (the
              // per-tile ones are deprecated, #89).
              RadioGroup<String>(
                groupValue: currentTheme,
                onChanged: (value) {
                  if (value != null) appState.setThemeMode(value);
                },
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      title: Text('Системная'),
                      value: 'system',
                    ),
                    RadioListTile<String>(
                      title: Text('Светлая'),
                      value: 'light',
                    ),
                    RadioListTile<String>(
                      title: Text('Тёмная'),
                      value: 'dark',
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.event_repeat),
                title: const Text('График работы'),
                subtitle: Text(
                  appState.workSchedule == null
                      ? 'Не задан'
                      : appState.workSchedule!.summary,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WorkScheduleScreen(),
                  ),
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Управление историей',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                title: const Text('Удалить историю за выбранный день'),
                leading: const Icon(Icons.delete_sweep, color: Colors.red),
                onTap: () => _deleteHistoryForDay(appState),
              ),
              ListTile(
                title: const Text('Очистить всю историю'),
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                onTap: () => _clearAllHistory(appState),
              ),
            ],
          );
        },
      ),
    );
  }
}
