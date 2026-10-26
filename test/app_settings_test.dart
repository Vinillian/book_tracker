import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:book_tracker/models/settings.dart';
import 'package:book_tracker/utils/work_schedule.dart';

void main() {
  test('AppSettings stores and restores the work schedule', () async {
    final dir = Directory.systemTemp.createTempSync('app_settings_');
    Hive.init(dir.path);
    Hive.registerAdapter(AppSettingsAdapter());
    final schedule = WorkSchedule(
      workDays: 2,
      offDays: 2,
      anchor: DateTime(2026, 10, 23),
    );
    var box = await Hive.openBox<AppSettings>('settings');
    await box.put(
      'appSettings',
      AppSettings(themeMode: 'dark', workSchedule: schedule.encode()),
    );
    await box.put('plain', AppSettings(themeMode: 'light'));
    await box.close();
    box = await Hive.openBox<AppSettings>('settings');
    final stored = box.get('appSettings')!;
    expect(stored.themeMode, 'dark');
    expect(
      WorkSchedule.tryParse(stored.workSchedule)!
          .dayTypeOf(DateTime(2026, 10, 25)),
      DayType.work,
    );
    expect(box.get('plain')!.workSchedule, isNull);
    await box.close();
    dir.deleteSync(recursive: true);
  });
}
