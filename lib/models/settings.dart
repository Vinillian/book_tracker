import 'package:hive_flutter/hive_flutter.dart';

part 'settings.g.dart';

@HiveType(typeId: 1)
class AppSettings {
  @HiveField(0)
  String themeMode;

  /// The work schedule as JSON (see `WorkSchedule`), null = no schedule (#144).
  @HiveField(1)
  String? workSchedule;

  AppSettings({required this.themeMode, this.workSchedule});
}
