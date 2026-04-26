import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/utils/file_transfer.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/models/note.dart';
import 'package:book_tracker/models/history_entry.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    // создаём временную директорию для тестов
    tempDir = Directory.systemTemp.createTempSync('book_tracker_test_');
    // инициализируем Hive в этой директории
    Hive.init(tempDir.path);
    Hive.registerAdapter(NodeAdapter());
    Hive.registerAdapter(NoteAdapter());
    Hive.registerAdapter(HistoryEntryAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    // удаляем временную директорию
    tempDir.deleteSync(recursive: true);
  });

  group('boxToJsonBytes / jsonBytesToItems', () {
    test('roundtrip with Node', () {
      final nodes = [
        Node(name: 'book', children: [Node.leaf('chapter')], category: 'book'),
        Node(name: 'day', children: [], category: 'planner', id: 'abc'),
      ];
      final bytes = FileTransfer.boxToJsonBytes(nodes);
      final items = FileTransfer.jsonBytesToItems(bytes);
      expect(items, isNotNull);
      expect(items!.length, 2);

      final restored = items.map(Node.fromJson).toList();
      expect(restored[0].name, 'book');
      expect(restored[1].id, 'abc');
    });

    test('preserves BOM and handles non‑BOM input', () {
      final notes = [Note(content: 'hello')];
      final bytes = FileTransfer.boxToJsonBytes(notes);
      // проверяем, что в начале есть BOM
      expect(bytes[0], 0xEF);
      expect(bytes[1], 0xBB);
      expect(bytes[2], 0xBF);

      // парсим обратно
      final items = FileTransfer.jsonBytesToItems(bytes);
      expect(items!.length, 1);
      final note = Note.fromJson(items.first);
      expect(note.content, 'hello');
    });

    test('returns null for invalid JSON', () {
      final invalid = Uint8List.fromList(utf8.encode('not json'));
      final items = FileTransfer.jsonBytesToItems(invalid);
      expect(items, isNull);
    });
  });

  group('import/export using temporary files', () {
    test('imports notes correctly', () async {
      // создаём временный файл с JSON
      final json = '''
[
  {"id":"1","title":"t1","content":"c1"},
  {"id":"2","title":"t2","content":"c2"}
]''';
      final file = File('${tempDir.path}/notes_import.json');
      await file.writeAsBytes(utf8.encode('\uFEFF$json'));

      // читаем байты и парсим
      final bytes = await file.readAsBytes();
      final items = FileTransfer.jsonBytesToItems(bytes);
      expect(items, isNotNull);
      expect(items!.length, 2);

      // добавляем в бокс
      final box = await Hive.openBox<Note>('notes_import_test');
      try {
        for (final item in items) {
          box.add(Note.fromJson(item));
        }
        expect(box.values.length, 2);
        expect(box.values.first.content, 'c1');
      } finally {
        await box.close();
      }
    });

    test('skips duplicates', () async {
      // создаём бокс с существующей заметкой
      final box = await Hive.openBox<Note>('notes_dup_test');
      try {
        await box.add(Note(id: '1', content: 'original'));

        // создаём файл с дубликатом
        final json = '[{"id":"1","content":"duplicate"}]';
        final file = File('${tempDir.path}/notes_dup.json');
        await file.writeAsBytes(utf8.encode('\uFEFF$json'));

        final bytes = await file.readAsBytes();
        final items = FileTransfer.jsonBytesToItems(bytes)!;
        int imported = 0;
        for (final item in items) {
          final note = Note.fromJson(item);
          final exists = box.values.any((n) => n.id == note.id);
          if (exists) continue;
          await box.add(note);
          imported++;
        }
        expect(imported, 0);
        expect(box.values.length, 1);
        expect(box.values.first.content, 'original');
      } finally {
        await box.close();
      }
    });
  });
}
