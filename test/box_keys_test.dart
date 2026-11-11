import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/models/note.dart';
import 'package:book_tracker/models/standard_task.dart';
import 'package:book_tracker/services/node_service.dart';
import 'package:book_tracker/services/note_service.dart';
import 'package:book_tracker/utils/box_keys.dart';

StandardTask task(String name, {String? id}) =>
    StandardTask(id: id, name: name, stepType: 'single');

Node book(String name) => Node(
      name: name,
      children: [Node.leaf('chapter')],
      category: 'book',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  var counter = 0;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('box_keys_test_');
    Hive.init(tempDir.path);
    Hive.registerAdapter(NodeAdapter());
    Hive.registerAdapter(NoteAdapter());
    Hive.registerAdapter(StandardTaskAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  Future<void> withBox<T>(Future<void> Function(Box<T> box) body) async {
    final box = await Hive.openBox<T>('box_${++counter}');
    try {
      await body(box);
    } finally {
      await box.close();
    }
  }

  group('findKeyById', () {
    test('finds an auto-increment key, even 0', () async {
      await withBox<StandardTask>((box) async {
        final first = task('first');
        final second = task('second');
        await box.add(first);
        await box.add(second);
        expect(findKeyById<StandardTask>(box, (t) => t.id, first.id), 0);
        expect(findKeyById<StandardTask>(box, (t) => t.id, second.id), 1);
      });
    });

    test('finds a key that is the id itself', () async {
      await withBox<StandardTask>((box) async {
        final t = task('named');
        await box.put(t.id, t);
        expect(findKeyById<StandardTask>(box, (x) => x.id, t.id), t.id);
      });
    });

    test('a record with the same id but another object finds the same key',
        () async {
      await withBox<StandardTask>((box) async {
        final stored = task('stored');
        await box.add(stored);
        final copy = task('edited copy', id: stored.id);
        expect(identical(copy, stored), isFalse);
        expect(findKeyById<StandardTask>(box, (t) => t.id, copy.id), 0);
      });
    });

    test('an unknown id, or an empty box, gives null', () async {
      await withBox<StandardTask>((box) async {
        expect(findKeyById<StandardTask>(box, (t) => t.id, 'x'), isNull);
        await box.add(task('only'));
        expect(findKeyById<StandardTask>(box, (t) => t.id, 'missing'), isNull);
      });
    });

    test('picks the right record among several', () async {
      await withBox<StandardTask>((box) async {
        final tasks = [for (var i = 0; i < 5; i++) task('t$i')];
        await box.addAll(tasks);
        for (var i = 0; i < tasks.length; i++) {
          expect(findKeyById<StandardTask>(box, (t) => t.id, tasks[i].id), i);
        }
      });
    });
  });

  group('NodeService.findKey / getKey', () {
    Future<void> withService(
      Future<void> Function(NodeService service, Box<Node> nodes) body,
    ) async {
      final n = ++counter;
      final nodes = await Hive.openBox<Node>('nodes_$n');
      final notes = await Hive.openBox<Note>('notes_$n');
      try {
        await body(NodeService(nodes, NoteService(notes)), nodes);
      } finally {
        await nodes.close();
        await notes.close();
      }
    }

    test('the very node that is stored', () async {
      await withService((service, nodes) async {
        final a = book('A');
        final b = book('B');
        await nodes.addAll([a, b]);
        expect(service.findKey(a), 0);
        expect(service.getKey(b), 1);
      });
    });

    test('a copy of a stored node finds the same key (#73)', () async {
      await withService((service, nodes) async {
        final stored = book('A');
        await nodes.add(stored);
        final copy = stored.deepCopy()..name = 'A edited';
        expect(identical(copy, stored), isFalse);
        expect(copy.id, stored.id);
        expect(service.findKey(copy), 0);
        expect(service.getKey(copy), 0);
      });
    });

    test('a node that is not stored: null, and a StateError from getKey',
        () async {
      await withService((service, nodes) async {
        await nodes.add(book('A'));
        final stranger = book('Stranger');
        expect(service.findKey(stranger), isNull);
        expect(() => service.getKey(stranger), throwsStateError);
      });
    });
  });

  group('NoteService.delete', () {
    Future<void> withNotes(
      Future<void> Function(NoteService service, Box<Note> box) body,
    ) async {
      final box = await Hive.openBox<Note>('notes_only_${++counter}');
      try {
        await body(NoteService(box), box);
      } finally {
        await box.close();
      }
    }

    test('a note stored under its id', () async {
      await withNotes((service, box) async {
        final note = Note(content: 'x');
        await box.put(note.id, note);
        service.delete(note.id);
        expect(box.isEmpty, isTrue);
      });
    });

    test('an old note stored under an auto-increment key', () async {
      await withNotes((service, box) async {
        final old = Note(content: 'old');
        final keep = Note(content: 'keep');
        await box.add(old);
        await box.add(keep);
        service.delete(old.id);
        expect(box.values.map((n) => n.content), ['keep']);
      });
    });

    test('an unknown id changes nothing and does not throw', () async {
      await withNotes((service, box) async {
        await box.add(Note(content: 'x'));
        service.delete('missing');
        expect(box.length, 1);
      });
    });
  });
}
