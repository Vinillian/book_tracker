import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/history_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
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
              RadioListTile<String>(
                title: const Text('Системная'),
                value: 'system',
                groupValue: currentTheme,
                onChanged: (value) {
                  if (value != null) appState.setThemeMode(value);
                },
              ),
              RadioListTile<String>(
                title: const Text('Светлая'),
                value: 'light',
                groupValue: currentTheme,
                onChanged: (value) {
                  if (value != null) appState.setThemeMode(value);
                },
              ),
              RadioListTile<String>(
                title: const Text('Тёмная'),
                value: 'dark',
                groupValue: currentTheme,
                onChanged: (value) {
                  if (value != null) appState.setThemeMode(value);
                },
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
                onTap: () async {
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (selectedDate == null) return;

                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Подтверждение'),
                      content: Text(
                        'Все записи истории за ${selectedDate.day}.${selectedDate.month}.${selectedDate.year} будут безвозвратно удалены. Продолжить?',
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
                  if (confirm == true && mounted) {
                    await HistoryService.deleteHistoryForDate(selectedDate);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'История за ${selectedDate.day}.${selectedDate.month}.${selectedDate.year} удалена',
                          ),
                        ),
                      );
                      appState.notify();
                    }
                  }
                },
              ),
              ListTile(
                title: const Text('Очистить всю историю'),
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                onTap: () async {
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
                  if (confirm == true && mounted) {
                    await HistoryService.clear();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Вся история удалена')),
                      );
                      appState.notify();
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}