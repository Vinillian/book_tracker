import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final String currentThemeMode;
  final Function(String)? onThemeChanged;

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
          ListTile(
            title: const Text('Системная'),
            leading: Radio<String>(
              value: 'system',
              groupValue: currentThemeMode,
              onChanged: (value) {
                if (value != null && onThemeChanged != null) {
                  onThemeChanged!(value);
                  Navigator.pop(context);
                }
              },
            ),
            onTap: () {
              if (onThemeChanged != null) {
                onThemeChanged!('system');
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            title: const Text('Светлая'),
            leading: Radio<String>(
              value: 'light',
              groupValue: currentThemeMode,
              onChanged: (value) {
                if (value != null && onThemeChanged != null) {
                  onThemeChanged!(value);
                  Navigator.pop(context);
                }
              },
            ),
            onTap: () {
              if (onThemeChanged != null) {
                onThemeChanged!('light');
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            title: const Text('Тёмная'),
            leading: Radio<String>(
              value: 'dark',
              groupValue: currentThemeMode,
              onChanged: (value) {
                if (value != null && onThemeChanged != null) {
                  onThemeChanged!(value);
                  Navigator.pop(context);
                }
              },
            ),
            onTap: () {
              if (onThemeChanged != null) {
                onThemeChanged!('dark');
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
