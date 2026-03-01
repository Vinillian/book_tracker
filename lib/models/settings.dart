import 'package:hive_flutter/hive_flutter.dart';

part 'settings.g.dart';

@HiveType(typeId: 1)
class AppSettings {
  @HiveField(0)
  String themeMode;

  AppSettings({required this.themeMode});
}
