import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final currentTheme = appState.themeMode;
          return RadioGroup<String>(
            groupValue: currentTheme,
            onChanged: (value) {
              if (value != null) {
                appState.setThemeMode(value);
              }
            },
            child: ListView(
              children: const [
                SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Тема оформления',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: Radio<String>(value: 'system'),
                  title: Text('Системная'),
                ),
                ListTile(
                  leading: Radio<String>(value: 'light'),
                  title: Text('Светлая'),
                ),
                ListTile(
                  leading: Radio<String>(value: 'dark'),
                  title: Text('Тёмная'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}