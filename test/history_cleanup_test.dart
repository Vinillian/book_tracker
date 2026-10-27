import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:book_tracker/models/history_entry.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/models/note.dart';
import 'package:book_tracker/services/history_service.dart';
import 'package:book_tracker/services/node_service.dart';
import 'package:book_tracker/services/note_service.dart';
import 'package:book_tracker/utils/node_ids.dart';

void main() {
  group('collectNodeIds', () {
    test('contains the root and every nested task', () {
      final deep = Node.leaf('deep');
      final mid = Node(name: 'mid', children: [deep], stepType: 'folder');
      final other = Node.leaf('other');
      final root = Node(
        name: 'root',
        children: [mid, other],
        category: 'planner',
        stepType: 'folder',
      );
      expect(
        collectNodeIds(root),
        {root.id, mid.id, deep.id, other.id},
      );
    });
  });

  group('History cleanup of deleted tasks (#84)', () {
    late Directory dir;
    late Box<Node> nodes;
    late Box<HistoryEntry> history;
    late Box<Note> notes;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('history_cleanup_test');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(NodeAdapter());
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(HistoryEntryAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(NoteAdapter());
      nodes = await Hive.openBox<Node>('nodes');
      history = await Hive.openBox<HistoryEntry>('history');
      notes = await Hive.openBox<Note>('notes');
      HistoryService.init(history);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    void done(Node root, Node task) {
      history.add(HistoryEntry.forSingle(
        bookId: root.id,
        nodeId: task.id,
        nodeName: task.name,
        completed: true,
        trackingId: task.trackingId,
        date: DateTime(2026, 10, 25),
      ));
    }

    Set<String> doneIds() => history.values.map((e) => e.nodeId).toSet();

    Node plan(List<Node> children) => Node(
          name: 'День',
          children: children,
          category: 'planner',
          stepType: 'folder',
        );

    test('deleteEntriesForTasks removes only the given tasks', () {
      final a = Node.leaf('a');
      final b = Node.leaf('b');
      final root = plan([a, b]);
      done(root, a);
      done(root, b);
      expect(HistoryService.deleteEntriesForTasks({b.id}), 1);
      expect(doneIds(), {a.id});
      expect(HistoryService.deleteEntriesForTasks({}), 0);
      expect(doneIds(), {a.id});
    });

    test('saving a copy without a task removes that task\'s entries',
        () async {
      final a = Node.leaf('a');
      final b = Node.leaf('b');
      final root = plan([a, b]);
      final key = await nodes.add(root);
      done(root, a);
      done(root, b);
      final service = NodeService(nodes, NoteService(notes));

      final edited = root.deepCopy()..children.removeWhere((c) => c.id == b.id);
      service.update(key, edited);

      expect(doneIds(), {a.id});
    });

    test('removing a task in place and saving is detected too', () async {
      final a = Node.leaf('a');
      final b = Node.leaf('b');
      final root = plan([a, b]);
      final key = await nodes.add(root);
      done(root, a);
      done(root, b);
      final service = NodeService(nodes, NoteService(notes));

      root.children.removeWhere((c) => c.id == a.id);
      service.update(key, root);

      expect(doneIds(), {b.id});
    });

    test('removing a task with subtasks removes the entries of all of them',
        () async {
      final sub = Node.leaf('sub');
      final parent = Node(name: 'parent', children: [sub], stepType: 'single');
      final keep = Node.leaf('keep');
      final root = plan([parent, keep]);
      final key = await nodes.add(root);
      done(root, parent);
      done(root, sub);
      done(root, keep);
      final service = NodeService(nodes, NoteService(notes));

      service.update(
        key,
        root.deepCopy()..children.removeWhere((c) => c.id == parent.id),
      );

      expect(doneIds(), {keep.id});
    });

    test('a save that removes nothing keeps every entry', () async {
      final a = Node.leaf('a');
      final root = plan([a]);
      final key = await nodes.add(root);
      done(root, a);
      final service = NodeService(nodes, NoteService(notes));

      final edited = root.deepCopy()
        ..name = 'Другое имя'
        ..children.add(Node.leaf('new'));
      service.update(key, edited);

      expect(doneIds(), {a.id});
    });

    test('entries of other roots are not touched', () async {
      final a = Node.leaf('a');
      final x = Node.leaf('x');
      final root = plan([a]);
      final other = plan([x]);
      final key = await nodes.add(root);
      await nodes.add(other);
      done(root, a);
      done(other, x);
      final service = NodeService(nodes, NoteService(notes));

      service.update(key, root.deepCopy()..children.clear());

      expect(doneIds(), {x.id});
    });

    test('a node added through the service is tracked from then on',
        () async {
      final a = Node.leaf('a');
      final b = Node.leaf('b');
      final root = plan([a, b]);
      final service = NodeService(nodes, NoteService(notes));
      await service.add(root);
      done(root, a);
      done(root, b);
      final key = nodes.keys.single;

      service.update(key, root.deepCopy()..children.removeAt(0));

      expect(doneIds(), {b.id});
    });
  });
}
