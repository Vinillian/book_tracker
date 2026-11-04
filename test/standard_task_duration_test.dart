import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:book_tracker/models/standard_task.dart';

class _LegacyStandardTaskAdapter extends TypeAdapter<StandardTask> {
  @override
  final int typeId = 4;

  @override
  StandardTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StandardTask(
      id: fields[0] as String?,
      name: fields[1] as String,
      stepType: fields[2] as String,
      totalSteps: fields[3] as int,
      excludeFromHistory: fields[4] as bool,
      colorValue: fields[5] as int?,
      trackingId: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, StandardTask obj) {
    // The schema used by older app versions had fields 0 through 6 only.
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.stepType)
      ..writeByte(3)
      ..write(obj.totalSteps)
      ..writeByte(4)
      ..write(obj.excludeFromHistory)
      ..writeByte(5)
      ..write(obj.colorValue)
      ..writeByte(6)
      ..write(obj.trackingId);
  }
}

void main() {
  group('StandardTask duration support', () {
    test('JSON round-trip preserves the duration goal', () {
      final task = StandardTask(
        name: 'Чтение',
        stepType: 'duration',
        targetMinutes: 45,
        trackingId: 'reading',
      );

      final restored = StandardTask.fromJson(task.toJson());

      expect(restored.stepType, 'single');
      expect(restored.targetMinutes, 45);
      expect(restored.trackingId, 'reading');
      expect(restored.toNode().targetMinutes, 45);
    });

    test('old JSON without a duration goal remains compatible', () {
      final task = StandardTask.fromJson({
        'id': 'old-task',
        'name': 'Зарядка',
        'stepType': 'single',
        'totalSteps': 1,
        'excludeFromHistory': false,
        'colorValue': null,
        'trackingId': 'old-tracking',
      });

      expect(task.targetMinutes, isNull);
      expect(task.stepType, 'single');
      expect(task.toNode().targetMinutes, isNull);
    });

    test('toNode copies duration type, goal, and tracking identity', () {
      final task = StandardTask(
        name: 'Практика',
        stepType: 'duration',
        targetMinutes: 90,
        trackingId: 'practice-tracking',
        excludeFromHistory: true,
      );

      final node = task.toNode();

      expect(node.stepType, 'single');
      expect(node.targetMinutes, 90);
      expect(node.trackingId, 'practice-tracking');
      expect(node.excludeFromHistory, isTrue);
      expect(node.timeGoalReached, isFalse);

      node.loggedMinutes = 90;
      expect(node.timeGoalReached, isTrue);
    });

    test('a task without a time goal can still log time independently', () {
      final node = StandardTask(
        name: 'Свободная практика',
        stepType: 'duration',
      ).toNode();

      expect(node.stepType, 'single');
      expect(node.targetMinutes, isNull);
      expect(node.timeGoalReached, isFalse);
      expect(node.isTimeTrackingEnabled, isTrue);
      node.loggedMinutes = 1;
      expect(node.timeGoalReached, isFalse);
    });

    test('progress description includes an optional goal', () {
      expect(
        StandardTask(
          name: 'Чтение',
          stepType: 'duration',
          targetMinutes: 30,
        ).progressDescription,
        'Одиночный чекбокс · цель времени: 30 мин',
      );
      expect(
        StandardTask(name: 'Медитация', stepType: 'duration')
            .progressDescription,
        'Одиночный чекбокс',
      );
    });
  });

  group('StandardTask Hive compatibility', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('standard_task_duration');
      Hive.init(directory.path);
      if (Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(StandardTaskAdapter(), override: true);
      } else {
        Hive.registerAdapter(StandardTaskAdapter());
      }
    });

    tearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });

    test('persists a duration goal', () async {
      var box = await Hive.openBox<StandardTask>('standard_tasks');
      await box.put(
        'duration',
        StandardTask(
          name: 'Бег',
          stepType: 'duration',
          targetMinutes: 60,
          trackingId: 'running',
        ),
      );

      await Hive.close();
      box = await Hive.openBox<StandardTask>('standard_tasks');

      expect(box.get('duration')!.stepType, 'single');
      expect(box.get('duration')!.targetMinutes, 60);
      expect(box.get('duration')!.trackingId, 'running');
    });

    test('reads a legacy Hive record without the new field', () async {
      Hive.registerAdapter(_LegacyStandardTaskAdapter(), override: true);
      var box = await Hive.openBox<StandardTask>('standard_tasks');
      await box.put(
        'legacy',
        StandardTask(
          name: 'Старое упражнение',
          stepType: 'stepByStep',
          totalSteps: 4,
          trackingId: 'legacy-tracking',
        ),
      );

      await Hive.close();
      Hive.registerAdapter(StandardTaskAdapter(), override: true);
      box = await Hive.openBox<StandardTask>('standard_tasks');

      final restored = box.get('legacy')!;
      expect(restored.name, 'Старое упражнение');
      expect(restored.stepType, 'stepByStep');
      expect(restored.totalSteps, 4);
      expect(restored.targetMinutes, isNull);
      expect(restored.trackingId, 'legacy-tracking');
    });
  });
}
