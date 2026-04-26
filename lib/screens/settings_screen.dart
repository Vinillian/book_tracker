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
      body: ListView(
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
            groupValue: currentThemeMode,
            onChanged: (value) => onThemeChanged(value!),
          ),
          RadioListTile<String>(
            title: const Text('Светлая'),
            value: 'light',
            groupValue: currentThemeMode,
            onChanged: (value) => onThemeChanged(value!),
          ),
          RadioListTile<String>(
            title: const Text('Тёмная'),
            value: 'dark',
            groupValue: currentThemeMode,
            onChanged: (value) => onThemeChanged(value!),
          ),
        ],
      ),
    );
  }
}
