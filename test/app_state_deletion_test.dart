import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:book_tracker/models/history_entry.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/models/note.dart';
import 'package:book_tracker/models/settings.dart';
import 'package:book_tracker/models/standard_task.dart';
import 'package:book_tracker/models/tracked_activity.dart';
import 'package:book_tracker/providers/app_state.dart';

Node book(String name) => Node(
      name: name,
      children: [Node.leaf('chapter')],
      category: 'book',
    );

Node plan(int day) => Node(
      name: 'P$day',
      children: [Node.leaf('task $day')],
      category: 'planner',
      plannedDate: DateTime(2026, 11, day),
    );

Note noteOf(Node node, String content) =>
    Note(content: content, linkedNodeId: node.id);

HistoryEntry entryOf(Node root, String id) => HistoryEntry(
      id: id,
      bookId: root.id,
      nodeId: root.children.first.id,
      date: DateTime(2026, 11, 1),
      nodeName: 'n',
      stepType: 'single',
      completed: true,
      trackingId: 't-$id',
    );

TrackedActivity activity(String id, String nodeId, String name) =>
    TrackedActivity(
      id: id,
      nodeId: nodeId,
      name: name,
      colorValue: 0xFF123456,
      stepType: 'single',
      isActive: true,
      isRoutine: true,
      order: 0,
    );

/// The boxes of one test, to seed before the AppState exists.
class Boxes {
  final Box<Node> nodes;
  final Box<Note> notes;
  final Box<HistoryEntry> history;
  final Box<StandardTask> standard;
  final Box<TrackedActivity> tracked;

  Boxes(this.nodes, this.notes, this.history, this.standard, this.tracked);
}

class Env extends Boxes {
  final AppState app;

  Env(this.app, Boxes b)
      : super(b.nodes, b.notes, b.history, b.standard, b.tracked);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  var counter = 0;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('app_state_test_');
    Hive.init(tempDir.path);
    Hive.registerAdapter(NodeAdapter());
    Hive.registerAdapter(NoteAdapter());
    Hive.registerAdapter(HistoryEntryAdapter());
    Hive.registerAdapter(StandardTaskAdapter());
    Hive.registerAdapter(TrackedActivityAdapter());
    Hive.registerAdapter(AppSettingsAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  /// Opens fresh boxes, lets [seed] fill them, then builds the AppState over
  /// them (as the app does at start) and runs [body].
  Future<void> withApp(
    Future<void> Function(Env env) body, {
    Future<void> Function(Boxes boxes)? seed,
  }) async {
    final n = ++counter;
    final nodes = await Hive.openBox<Node>('nodes_$n');
    final notes = await Hive.openBox<Note>('notes_$n');
    final history = await Hive.openBox<HistoryEntry>('history_$n');
    final standard = await Hive.openBox<StandardTask>('standard_$n');
    final tracked = await Hive.openBox<TrackedActivity>('tracked_$n');
    final settings = await Hive.openBox<AppSettings>('settings_$n');
    try {
      final boxes = Boxes(nodes, notes, history, standard, tracked);
      if (seed != null) await seed(boxes);
      final app = AppState(
        templatesBox: nodes,
        notesBox: notes,
        historyBox: history,
        standardTasksBox: standard,
        trackedActivitiesBox: tracked,
        settingsBox: settings,
      );
      await body(Env(app, boxes));
    } finally {
      await nodes.close();
      await notes.close();
      await history.close();
      await standard.close();
      await tracked.close();
      await settings.close();
    }
  }

  group('hide, restore and commit the deletion of a node', () {
    test('hiding takes a book out of the lists, nothing is erased', () async {
      await withApp(
        (env) async {
          final a = env.app.books.first;
          env.app.hideNodeForDeletion(a);
          expect(env.app.books.map((b) => b.name), ['B']);
          expect(env.nodes.length, 2);
          env.app.restoreNode(a);
          expect(env.app.books.map((b) => b.name), ['A', 'B']);
        },
        seed: (env) async {
          await env.nodes.addAll([book('A'), book('B')]);
        },
      );
    });

    test('committing erases the node, its notes and its History only',
        () async {
      await withApp(
        (env) async {
          final a = env.app.books.firstWhere((b) => b.name == 'A');
          env.app.hideNodeForDeletion(a);
          env.app.commitNodeDeletion(a);

          expect(env.nodes.values.map((n) => n.name), ['B']);
          expect(env.notes.values.map((n) => n.content), ['note of B']);
          expect(env.history.values.map((h) => h.id), ['h-B']);
        },
        seed: (env) async {
          final a = book('A');
          final b = book('B');
          await env.nodes.addAll([a, b]);
          await env.notes.addAll([noteOf(a, 'note of A'), noteOf(b, 'note of B')]);
          await env.history.addAll([entryOf(a, 'h-A'), entryOf(b, 'h-B')]);
        },
      );
    });

    test('committing a node that was not hidden does nothing', () async {
      await withApp(
        (env) async {
          final a = env.app.books.first;
          env.app.commitNodeDeletion(a);
          expect(env.nodes.length, 1);
          expect(env.notes.length, 1);
        },
        seed: (env) async {
          final a = book('A');
          await env.nodes.add(a);
          await env.notes.add(noteOf(a, 'keep'));
        },
      );
    });

    test('committing a node that is already gone does not throw', () async {
      await withApp(
        (env) async {
          final a = env.app.books.first;
          env.app.hideNodeForDeletion(a);
          await env.nodes.clear();
          expect(() => env.app.commitNodeDeletion(a), returnsNormally);
        },
        seed: (env) async {
          await env.nodes.add(book('A'));
        },
      );
    });

    test('a copy of the node (same id) is deleted too (#73)', () async {
      await withApp(
        (env) async {
          final stored = env.app.books.first;
          final copy = stored.deepCopy();
          env.app.hideNodeForDeletion(copy);
          env.app.commitNodeDeletion(copy);
          expect(env.nodes.isEmpty, isTrue);
          expect(env.notes.isEmpty, isTrue);
        },
        seed: (env) async {
          final a = book('A');
          await env.nodes.add(a);
          await env.notes.add(noteOf(a, 'x'));
        },
      );
    });

    test('a hidden plan is not found for its date until it is restored',
        () async {
      await withApp(
        (env) async {
          final day = DateTime(2026, 11, 5);
          final p = env.app.planForDate(day)!;
          env.app.hideNodeForDeletion(p);
          expect(env.app.planForDate(day), isNull);
          env.app.restoreNode(p);
          expect(env.app.planForDate(day), isNotNull);
        },
        seed: (env) async {
          await env.nodes.add(plan(5));
        },
      );
    });

    test('the listeners hear each step once, and nothing when nothing changed',
        () async {
      await withApp(
        (env) async {
          var heard = 0;
          env.app.addListener(() => heard++);
          final a = env.app.books.first;

          env.app.restoreNode(a); // not hidden: nothing to restore
          expect(heard, 0);
          env.app.hideNodeForDeletion(a);
          expect(heard, 1);
          env.app.restoreNode(a);
          expect(heard, 2);
        },
        seed: (env) async {
          await env.nodes.add(book('A'));
        },
      );
    });
  });

  group('several nodes at once', () {
    test('hide all, restore one, commit all: only the still hidden are erased',
        () async {
      await withApp(
        (env) async {
          final a = env.app.plans.firstWhere((p) => p.name == 'P1');
          final b = env.app.plans.firstWhere((p) => p.name == 'P2');
          final c = env.app.plans.firstWhere((p) => p.name == 'P3');
          env.app.hideNodesForDeletion([a, b, c]);
          expect(env.app.plans, isEmpty);

          env.app.restoreNodes([a]);
          expect(env.app.plans.map((p) => p.name), ['P1']);

          env.app.commitNodesDeletion([a, b, c]);
          expect(env.nodes.values.map((n) => n.name), ['P1']);
          expect(env.notes.values.map((n) => n.content), ['of P1']);
        },
        seed: (env) async {
          final a = plan(1);
          final b = plan(2);
          final c = plan(3);
          await env.nodes.addAll([a, b, c]);
          await env.notes.addAll([
            noteOf(a, 'of P1'),
            noteOf(b, 'of P2'),
            noteOf(c, 'of P3'),
          ]);
        },
      );
    });

    test('one notification for a whole batch', () async {
      await withApp(
        (env) async {
          var heard = 0;
          env.app.addListener(() => heard++);
          final all = env.app.plans;
          env.app.hideNodesForDeletion(all);
          expect(heard, 1);
          env.app.commitNodesDeletion(all);
          expect(heard, 2);
          env.app.restoreNodes(all); // nothing is hidden any more
          expect(heard, 2);
        },
        seed: (env) async {
          await env.nodes.addAll([plan(1), plan(2), plan(3)]);
        },
      );
    });

    test('copies of the nodes are erased as well (#73)', () async {
      await withApp(
        (env) async {
          final copies = [for (final p in env.app.plans) p.deepCopy()];
          env.app.hideNodesForDeletion(copies);
          env.app.commitNodesDeletion(copies);
          expect(env.nodes.isEmpty, isTrue);
        },
        seed: (env) async {
          await env.nodes.addAll([plan(1), plan(2)]);
        },
      );
    });
  });

  group('saving a node through the key of a copy', () {
    test('the stored node takes the edited copy', () async {
      await withApp(
        (env) async {
          final stored = env.app.books.first;
          final copy = stored.deepCopy()..name = 'A edited';
          env.app.updateNode(env.app.getKeyForNode(copy), copy);
          expect(env.nodes.length, 1);
          expect(env.nodes.values.single.name, 'A edited');
        },
        seed: (env) async {
          await env.nodes.add(book('A'));
        },
      );
    });
  });

  group('standard tasks by id', () {
    StandardTask std(String id, String name, {String trackingId = 't'}) =>
        StandardTask(
          id: id,
          name: name,
          stepType: 'single',
          trackingId: trackingId,
        );

    test('update replaces the task with that id, the others stay', () async {
      await withApp(
        (env) async {
          env.app.updateStandardTask('b', std('b', 'B renamed'));
          expect(
            env.standard.values.map((t) => t.name),
            ['A', 'B renamed', 'C'],
          );
        },
        seed: (env) async {
          await env.standard.addAll([std('a', 'A'), std('b', 'B'), std('c', 'C')]);
        },
      );
    });

    test('update and delete work for tasks stored under their id too',
        () async {
      await withApp(
        (env) async {
          env.app.updateStandardTask('x', std('x', 'X renamed'));
          expect(env.standard.get('x')!.name, 'X renamed');
          env.app.deleteStandardTask('x');
          expect(env.standard.isEmpty, isTrue);
        },
        seed: (env) async {
          await env.standard.put('x', std('x', 'X'));
        },
      );
    });

    test('an unknown id changes nothing and does not notify', () async {
      await withApp(
        (env) async {
          var heard = 0;
          env.app.addListener(() => heard++);
          env.app.updateStandardTask('nope', std('nope', 'N'));
          env.app.deleteStandardTask('nope');
          expect(env.standard.length, 1);
          expect(heard, 0);
        },
        seed: (env) async {
          await env.standard.add(std('a', 'A'));
        },
      );
    });

    test('delete removes only the task with that id', () async {
      await withApp(
        (env) async {
          env.app.deleteStandardTask('b');
          expect(env.standard.values.map((t) => t.id), ['a', 'c']);
        },
        seed: (env) async {
          await env.standard.addAll([std('a', 'A'), std('b', 'B'), std('c', 'C')]);
        },
      );
    });

    test('renaming a standard task reaches its tracked activity (#173)',
        () async {
      await withApp(
        (env) async {
          env.app.updateStandardTask(
            's1',
            std('s1', 'Чтение книг', trackingId: 'X'),
          );
          final a = env.tracked.values.firstWhere((t) => t.id == 'a1');
          final other = env.tracked.values.firstWhere((t) => t.id == 'a2');
          expect(a.name, 'Чтение книг');
          expect(a.nodeId, 'X');
          expect(other.name, 'Йога');
        },
        seed: (env) async {
          await env.standard.add(std('s1', 'Чтение', trackingId: 'X'));
          await env.tracked.addAll([
            activity('a1', 'X', 'Чтение'),
            activity('a2', 'Y', 'Йога'),
          ]);
        },
      );
    });
  });

  group('tracked activities by id', () {
    test('update and delete find the activity by its id', () async {
      await withApp(
        (env) async {
          env.app.updateTrackedActivity('a2', activity('a2', 'Y', 'Йога утром'));
          expect(
            env.tracked.values.map((t) => t.name),
            ['Чтение', 'Йога утром', 'Бег'],
          );
          env.app.deleteTrackedActivity('a1');
          expect(env.tracked.values.map((t) => t.id), ['a2', 'a3']);
        },
        seed: (env) async {
          await env.tracked.addAll([
            activity('a1', 'X', 'Чтение'),
            activity('a2', 'Y', 'Йога'),
            activity('a3', 'Z', 'Бег'),
          ]);
        },
      );
    });

    test('an unknown id changes nothing', () async {
      await withApp(
        (env) async {
          env.app.updateTrackedActivity('nope', activity('nope', 'N', 'N'));
          env.app.deleteTrackedActivity('nope');
          expect(env.tracked.length, 1);
        },
        seed: (env) async {
          await env.tracked.add(activity('a1', 'X', 'Чтение'));
        },
      );
    });
  });
}
