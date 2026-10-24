import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/node_copy.dart';
import 'package:book_tracker/utils/template_target.dart';

Node template(String? target) => Node(
      name: 'T',
      children: [Node.leaf('a')],
      category: 'template',
      templateTarget: target,
    );

void main() {
  group('Node.templateTarget', () {
    test('survives toJson / fromJson and deepCopy', () {
      final t = template(templateTargetDay);
      expect(Node.fromJson(t.toJson()).templateTarget, 'day');
      expect(t.deepCopy().templateTarget, 'day');
    });

    test('old JSON without the field imports as "any" (null)', () {
      final json = template(null).toJson()..remove('templateTarget');
      expect(Node.fromJson(json).templateTarget, isNull);
    });

    test('Hive adapter stores and restores it', () async {
      final dir = Directory.systemTemp.createTempSync('template_target_');
      Hive.init(dir.path);
      Hive.registerAdapter(NodeAdapter());
      var box = await Hive.openBox<Node>('nodes');
      await box.put('a', template(templateTargetBook));
      await box.put('b', template(null));
      await box.close();
      box = await Hive.openBox<Node>('nodes');
      expect(box.get('a')!.templateTarget, 'book');
      expect(box.get('b')!.templateTarget, isNull);
      await box.close();
      dir.deleteSync(recursive: true);
    });

    test('copyAndReset clears it: a day made from a template is no template',
        () {
      final copy = copyAndReset(template(templateTargetDay));
      expect(copy.templateTarget, isNull);
    });
  });

  group('template targets', () {
    test('category maps to the needed target', () {
      expect(templateTargetForCategory('planner'), 'day');
      expect(templateTargetForCategory('book'), 'book');
      expect(templateTargetForCategory(null), isNull);
      expect(templateTargetForCategory('template'), isNull);
    });

    test('matching: exact target or no target; no filter matches all', () {
      expect(templateMatchesTarget(template('day'), 'day'), isTrue);
      expect(templateMatchesTarget(template('book'), 'day'), isFalse);
      expect(templateMatchesTarget(template(null), 'day'), isTrue);
      expect(templateMatchesTarget(template(null), 'book'), isTrue);
      expect(templateMatchesTarget(template('book'), null), isTrue);
    });

    test('labels', () {
      expect(templateTargetLabel('day'), 'Для дня');
      expect(templateTargetLabel('book'), 'Для книги');
      expect(templateTargetLabel(null), 'Любой');
    });
  });
}
