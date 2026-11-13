import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:book_tracker/models/tracked_activity.dart';
import 'package:book_tracker/services/hive_startup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync(
      'tracked_activity_migration_test_',
    );
    Hive.init(tempDir.path);
    registerAppHiveAdapters();
  });

  tearDown(() async {
    await Hive.close();
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('migrates legacy nodeId and preserves data after restart', () async {
    final names = HiveBoxNames.prefixed('migration');
    final boxName = names.trackedActivities;

    // Simulate a record written by the previous application version.
    Hive.registerAdapter(_LegacyTrackedActivityAdapter(), override: true);

    final legacyBox = await Hive.openBox<TrackedActivity>(boxName);
    await legacyBox.put(
      'activity-key',
      TrackedActivity(
        id: 'activity-id',
        trackingId: '',
        legacyNodeId: 'legacy-tracking-id',
        name: 'Reading',
        colorValue: 0xFF2196F3,
        stepType: 'single',
        isActive: true,
        isRoutine: true,
        order: 7,
        timeTrackingEnabled: true,
      ),
    );
    await legacyBox.close();

    // Open the same file with the current adapter and startup migration.
    Hive.registerAdapter(TrackedActivityAdapter(), override: true);

    final startup = HiveStartup(
      names: names,
      openBox: <T>(String name) => Hive.openBox<T>(name),
    );

    // Startup opens the same box file containing the legacy record.
    // Migration must process that record directly.
    final boxes = await startup.open();

    final migrated = boxes.trackedActivitiesBox.get('activity-key')!;

    expect(migrated.id, 'activity-id');
    expect(migrated.trackingId, 'legacy-tracking-id');
    expect(migrated.name, 'Reading');
    expect(migrated.colorValue, 0xFF2196F3);
    expect(migrated.stepType, 'single');
    expect(migrated.isActive, isTrue);
    expect(migrated.isRoutine, isTrue);
    expect(migrated.order, 7);
    expect(migrated.timeTrackingEnabled, isTrue);

    // ignore: deprecated_member_use
    expect(migrated.legacyNodeId, '');

    // A second migration must not rewrite the record.
    expect(
      await migrateLegacyTrackedActivityIds(boxes.trackedActivitiesBox),
      0,
    );

    await boxes.trackedActivitiesBox.close();
    await boxes.standardTasksBox.close();
    await boxes.notesBox.close();
    await boxes.historyBox.close();
    await boxes.settingsBox.close();
    await boxes.templatesBox.close();

    // Reopen the migrated box and verify persistence.
    final reopened = await startup.open();
    final restored = reopened.trackedActivitiesBox.get('activity-key')!;

    expect(restored.id, 'activity-id');
    expect(restored.trackingId, 'legacy-tracking-id');
    expect(restored.name, 'Reading');
    // ignore: deprecated_member_use
    expect(restored.legacyNodeId, '');

    await reopened.trackedActivitiesBox.close();
    await reopened.standardTasksBox.close();
    await reopened.notesBox.close();
    await reopened.historyBox.close();
    await reopened.settingsBox.close();
    await reopened.templatesBox.close();
  });
}

/// Adapter matching the old TrackedActivity Hive schema (fields 0–8).
class _LegacyTrackedActivityAdapter extends TrackedActivityAdapter {
  @override
  void write(BinaryWriter writer, TrackedActivity obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      // ignore: deprecated_member_use
      ..write(obj.legacyNodeId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.stepType)
      ..writeByte(5)
      ..write(obj.isActive)
      ..writeByte(6)
      ..write(obj.isRoutine)
      ..writeByte(7)
      ..write(obj.order)
      ..writeByte(8)
      ..write(obj.timeTrackingEnabled);
  }
}
