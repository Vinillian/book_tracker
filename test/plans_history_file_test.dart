import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/history_entry.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/file_transfer.dart';
import 'package:hive_flutter/hive_flutter.dart';

Node plan(int day, {String? title}) => Node(
      name: title ?? 'P$day',
      children: [Node.leaf('task $day')],
      category: 'planner',
      plannedDate: DateTime(2026, 10, day),
    );

Node book() => Node(
      name: 'Book',
      children: [Node.leaf('chapter')],
      category: 'book',
    );

HistoryEntry entry(String id, String nodeId, int day) => HistoryEntry(
      id: id,
      bookId: 'b',
      nodeId: nodeId,
      date: DateTime(2026, 10, day),
      nodeName: 'n',
      stepType: 'single',
      completed: true,
      trackingId: 't-$id',
    );

String taskIdOf(Node plan) => plan.children.first.id;

ExportDateRange range(int from, int to) => ExportDateRange(
      start: DateTime(2026, 10, from),
      end: DateTime(2026, 10, to),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  var counter = 0;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('plans_history_test_');
    Hive.init(tempDir.path);
    Hive.registerAdapter(NodeAdapter());
    Hive.registerAdapter(HistoryEntryAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  Future<void> withBoxes(
    Future<void> Function(Box<Node> templates, Box<HistoryEntry> history) body,
  ) async {
    final n = ++counter;
    final templates = await Hive.openBox<Node>('templates_$n');
    final history = await Hive.openBox<HistoryEntry>('history_$n');
    try {
      await body(templates, history);
    } finally {
      await templates.close();
      await history.close();
    }
  }

  List<Node> plansIn(Box<Node> box) =>
      box.values.where((n) => n.category == 'planner').toList();

  group('selectPlansHistory', () {
    final template = Node(name: 'T', children: [], category: 'template');

    test('without a range: every plan and all history, nothing else', () {
      final p25 = plan(25);
      final p26 = plan(26);
      final result = FileTransfer.selectPlansHistory(
        templates: [p25, book(), template, p26],
        history: [entry('a', 'x', 25), entry('b', 'y', 1)],
      );
      expect(result.plans, [p25, p26]);
      expect(result.history.map((h) => h.id), ['a', 'b']);
    });

    test('with a range: only plans and history of those days', () {
      final p25 = plan(25);
      final p26 = plan(26);
      final p28 = plan(28);
      final undated = Node(
        name: 'Free title',
        children: [Node.leaf('a')],
        category: 'planner',
      );
      final result = FileTransfer.selectPlansHistory(
        templates: [p25, p28, undated, p26, book()],
        history: [entry('in', 'x', 26), entry('out', 'y', 27)],
        range: range(25, 26),
      );
      expect(result.plans, [p25, p26]);
      expect(result.history.map((h) => h.id), ['in']);
    });
  });

  group('one file', () {
    test('survives writing and parsing, ids and range included', () {
      final p = plan(25);
      final h = entry('h1', taskIdOf(p), 25);
      final bytes = FileTransfer.plansHistoryToJsonBytes(
        plans: [p.toJson()],
        history: [h.toJson()],
        exportedRange: range(25, 26),
      );
      final file = FileTransfer.parsePlansHistoryFile(bytes)!;
      expect(file.plans.length, 1);
      expect(file.history.length, 1);
      expect(file.exportedRange!.start, DateTime(2026, 10, 25));
      expect(file.exportedRange!.end, DateTime(2026, 10, 26));

      final back = Node.fromJson(file.plans.first);
      expect(back.id, p.id);
      expect(taskIdOf(back), taskIdOf(p));
      expect(HistoryEntry.fromJson(file.history.first).nodeId, taskIdOf(p));
    });

    test('a file without a range has none after reading', () {
      final bytes = FileTransfer.plansHistoryToJsonBytes(
        plans: [plan(25).toJson()],
        history: const [],
      );
      expect(FileTransfer.parsePlansHistoryFile(bytes)!.exportedRange, isNull);
    });

    test('anything else is not a plans + history file', () {
      final legacyPlans = FileTransfer.categoryToJsonBytes(
        category: 'planner',
        items: [plan(25).toJson()],
      );
      final legacyHistory = FileTransfer.categoryToJsonBytes(
        category: 'history',
        items: [entry('a', 'x', 25).toJson()],
      );
      final bareList = FileTransfer.boxToJsonBytes([plan(25)]);
      final garbage = Uint8List.fromList(utf8.encode('not json at all'));
      final noLists = Uint8List.fromList(
        utf8.encode(jsonEncode({'category': 'plansHistory'})),
      );
      final wrongCategory = Uint8List.fromList(
        utf8.encode(jsonEncode({'category': 'note', 'plans': [], 'history': []})),
      );
      for (final bytes in [
        legacyPlans,
        legacyHistory,
        bareList,
        garbage,
        noLists,
        wrongCategory,
      ]) {
        expect(FileTransfer.parsePlansHistoryFile(bytes), isNull);
      }
    });
  });

  group('applyPlansWithHistory', () {
    test('replaces the plans of the range and their history, keeps the rest',
        () async {
      await withBoxes((templates, history) async {
        final old25 = plan(25, title: 'old 25');
        final old30 = plan(30);
        final theBook = book();
        await templates.addAll([old25, old30, theBook]);
        await history.addAll([
          entry('h-old25', taskIdOf(old25), 25),
          entry('h-old30', taskIdOf(old30), 30),
          entry('h-book', theBook.children.first.id, 25),
        ]);

        final new25 = plan(25, title: 'new 25');
        final count = await FileTransfer.applyPlansWithHistory(
          templatesBox: templates,
          historyBox: history,
          plans: [new25],
          history: [entry('h-new25', taskIdOf(new25), 25)],
          range: range(25, 26),
        );

        expect(count, 2);
        expect(
          plansIn(templates).map((n) => n.name).toSet(),
          {'new 25', 'P30'},
        );
        expect(templates.values.any((n) => n.category == 'book'), isTrue);
        expect(
          history.values.map((h) => h.id).toSet(),
          {'h-old30', 'h-book', 'h-new25'},
        );
      });
    });

    test('without a range every plan is replaced, books stay', () async {
      await withBoxes((templates, history) async {
        await templates.addAll([plan(25), plan(30), book()]);
        await FileTransfer.applyPlansWithHistory(
          templatesBox: templates,
          historyBox: history,
          plans: [plan(27, title: 'only one')],
          history: const [],
        );
        expect(plansIn(templates).map((n) => n.name), ['only one']);
        expect(templates.values.where((n) => n.category == 'book').length, 1);
      });
    });

    test('importing the same file again does not duplicate history', () async {
      await withBoxes((templates, history) async {
        final theBook = book();
        await templates.add(theBook);
        final bookEntry = entry('h-book', theBook.children.first.id, 25);
        await history.add(bookEntry);

        final p = plan(25);
        final file = FileTransfer.plansHistoryToJsonBytes(
          plans: [p.toJson()],
          history: [
            entry('h-plan', taskIdOf(p), 25).toJson(),
            bookEntry.toJson(),
          ],
          exportedRange: range(25, 25),
        );

        for (var i = 0; i < 2; i++) {
          final parsed = FileTransfer.parsePlansHistoryFile(file)!;
          await FileTransfer.applyPlansWithHistory(
            templatesBox: templates,
            historyBox: history,
            plans: parsed.plans.map(Node.fromJson).toList(),
            history: parsed.history.map(HistoryEntry.fromJson).toList(),
            range: parsed.exportedRange,
          );
        }

        expect(plansIn(templates).length, 1);
        expect(history.values.map((h) => h.id).toList()..sort(),
            ['h-book', 'h-plan']);
      });
    });

    test('a file without plans removes no plan and only adds history',
        () async {
      await withBoxes((templates, history) async {
        await templates.add(plan(25));
        final count = await FileTransfer.applyPlansWithHistory(
          templatesBox: templates,
          historyBox: history,
          plans: const [],
          history: [entry('h1', 'somewhere', 25)],
          range: range(25, 26),
        );
        expect(count, 1);
        expect(plansIn(templates).length, 1);
        expect(history.values.map((h) => h.id), ['h1']);
      });
    });

    test('export, write, read and apply into empty boxes gives the same data',
        () async {
      final p25 = plan(25);
      final p26 = plan(26);
      final selected = FileTransfer.selectPlansHistory(
        templates: [p25, p26, plan(30)],
        history: [
          entry('a', taskIdOf(p25), 25),
          entry('b', taskIdOf(p26), 26),
          entry('c', 'other', 30),
        ],
        range: range(25, 26),
      );
      final bytes = FileTransfer.plansHistoryToJsonBytes(
        plans: [for (final p in selected.plans) p.toJson()],
        history: [for (final h in selected.history) h.toJson()],
        exportedRange: range(25, 26),
      );
      final parsed = FileTransfer.parsePlansHistoryFile(bytes)!;

      await withBoxes((templates, history) async {
        final count = await FileTransfer.applyPlansWithHistory(
          templatesBox: templates,
          historyBox: history,
          plans: parsed.plans.map(Node.fromJson).toList(),
          history: parsed.history.map(HistoryEntry.fromJson).toList(),
          range: parsed.exportedRange,
        );
        expect(count, 4);
        expect(plansIn(templates).map((n) => n.name).toSet(), {'P25', 'P26'});
        expect(history.values.map((h) => h.id).toSet(), {'a', 'b'});
      });
    });
  });
}
