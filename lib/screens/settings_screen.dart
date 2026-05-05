import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final String currentThemeMode;
  final Function(String) onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: RadioGroup<String>(
        groupValue: currentThemeMode,
        onChanged: (value) =>
            onThemeChanged(value!), // <-- добавили ! для String?
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
      ),
    );
  }
}
