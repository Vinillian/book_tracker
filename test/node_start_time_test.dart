import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/day_part.dart';

void main() {
  group('Node.startMinutes', () {
    test('survives toJson / fromJson and deepCopy', () {
      final node = Node.leaf('Run')..startMinutes = 7 * 60 + 5;
      expect(Node.fromJson(node.toJson()).startMinutes, 425);
      expect(node.deepCopy().startMinutes, 425);
    });

    test('old JSON without the field imports with no time', () {
      final json = Node.leaf('Old').toJson()..remove('startMinutes');
      expect(Node.fromJson(json).startMinutes, isNull);
    });

    test('Hive adapter stores and restores it', () async {
      final dir = Directory.systemTemp.createTempSync('node_start_time_');
      Hive.init(dir.path);
      Hive.registerAdapter(NodeAdapter());
      var box = await Hive.openBox<Node>('nodes');
      await box.put('a', Node.leaf('A')..startMinutes = 510);
      await box.put('b', Node.leaf('B'));
      await box.close();
      box = await Hive.openBox<Node>('nodes');
      expect(box.get('a')!.startMinutes, 510);
      expect(box.get('b')!.startMinutes, isNull);
      await box.close();
      dir.deleteSync(recursive: true);
    });
  });

  group('day parts', () {
    test('boundaries', () {
      expect(dayPartOf(null), DayPart.none);
      expect(dayPartOf(0), DayPart.morning);
      expect(dayPartOf(11 * 60 + 59), DayPart.morning);
      expect(dayPartOf(12 * 60), DayPart.day);
      expect(dayPartOf(17 * 60 + 59), DayPart.day);
      expect(dayPartOf(18 * 60), DayPart.evening);
      expect(dayPartOf(23 * 60 + 59), DayPart.evening);
    });

    test('formatMinutes pads with zeros', () {
      expect(formatMinutes(0), '00:00');
      expect(formatMinutes(510), '08:30');
      expect(formatMinutes(23 * 60 + 59), '23:59');
    });

    test('sortedByStartTime sorts by time and keeps order for equal times', () {
      final a = Node.leaf('a')..startMinutes = 600;
      final b = Node.leaf('b')..startMinutes = 480;
      final c = Node.leaf('c')..startMinutes = 600;
      final names = sortedByStartTime([a, b, c]).map((n) => n.name).toList();
      expect(names, ['b', 'a', 'c']);
    });
  });
}
