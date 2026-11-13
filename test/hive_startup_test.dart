import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/providers/app_state.dart';
import 'package:book_tracker/services/history_service.dart';
import 'package:book_tracker/services/hive_startup.dart';
import 'package:book_tracker/services/node_service.dart';
import 'package:book_tracker/services/note_service.dart';
import 'package:book_tracker/utils/plan_date.dart';

Node plan(String id, String name) => Node(
      id: id,
      name: name,
      children: [],
      category: 'planner',
    );

Node legacyBook() => Node(
      name: 'Legacy book',
      children: [
        Node(
          name: 'Part',
          category: 'book',
          children: [Node.leaf('Chapter', category: 'book')],
        ),
      ],
      category: 'book',
    );

Future<void> closeBoxes(OpenedHiveBoxes boxes) async {
  await boxes.trackedActivitiesBox.close();
  await boxes.standardTasksBox.close();
  await boxes.notesBox.close();
  await boxes.historyBox.close();
  await boxes.settingsBox.close();
  await boxes.templatesBox.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  var counter = 0;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('hive_startup_test_');
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

  HiveBoxNames nextNames() => HiveBoxNames.prefixed('startup_${++counter}');

  HiveStartup startupFor(HiveBoxNames names, {HiveBoxOpener? opener}) =>
      HiveStartup(
        names: names,
        openBox: opener ?? <T>(String name) => Hive.openBox<T>(name),
      );

  test('opens all required boxes and constructs AppState over live boxes',
      () async {
    final names = nextNames();
    final seed = await Hive.openBox<Node>(names.templates);
    await seed.put('legacy-plan', plan('template-workday', '02.11.2026'));
    await seed.put('legacy-book', legacyBook());
    await seed.close();

    final startup = startupFor(names);
    final boxes = await startup.open();

    expect(Hive.isBoxOpen(names.templates), isTrue);
    expect(Hive.isBoxOpen(names.settings), isTrue);
    expect(Hive.isBoxOpen(names.history), isTrue);
    expect(Hive.isBoxOpen(names.notes), isTrue);
    expect(Hive.isBoxOpen(names.standardTasks), isTrue);
    expect(Hive.isBoxOpen(names.trackedActivities), isTrue);

    final appState = AppState(
      templatesBox: boxes.templatesBox,
      notesBox: boxes.notesBox,
      historyBox: boxes.historyBox,
      standardTasksBox: boxes.standardTasksBox,
      trackedActivitiesBox: boxes.trackedActivitiesBox,
      settingsBox: boxes.settingsBox,
    );

    final migratedPlan = appState.plans.single;
    expect(migratedPlan.id, isNot('template-workday'));
    expect(migratedPlan.plannedDate, DateTime(2026, 11, 2));
    expect(planDateOf(migratedPlan), DateTime(2026, 11, 2));

    final migratedBook = appState.books.single;
    expect(migratedBook.children.single.category, isNull);
    expect(migratedBook.children.single.children.single.category, isNull);
    expect(appState.themeMode, 'system');

    expect(migrateLegacyPlanIds(
      boxes.templatesBox,
      boxes.notesBox,
      HistoryService(boxes.historyBox),
    ), 0);
    final nodeService = NodeService(
      boxes.templatesBox,
      NoteService(boxes.notesBox),
      HistoryService(boxes.historyBox),
    );
    expect(nodeService.migratePlannedDates(), 0);
    expect(nodeService.migrateNestedBookCategories(), 0);

    final migratedPlanId = migratedPlan.id;
    appState.dispose();
    await closeBoxes(boxes);

    final afterRestart = await startup.open();
    expect(afterRestart.templatesBox.get('legacy-plan')!.id, migratedPlanId);
    expect(
      afterRestart.templatesBox.get('legacy-plan')!.plannedDate,
      DateTime(2026, 11, 2),
    );
    expect(
      afterRestart.templatesBox
          .get('legacy-book')!
          .children
          .single
          .children
          .single
          .category,
      isNull,
    );
    await closeBoxes(afterRestart);
  });

  test('a later open failure closes prior boxes and preserves their files',
      () async {
    final names = nextNames();
    final seed = await Hive.openBox<Node>(names.templates);
    await seed.put('keep', Node.leaf('Existing data', id: 'keep-id'));
    await seed.close();

    Future<Box<T>> failAtHistory<T>(String name) {
      if (name == names.history) {
        return Future<Box<T>>.error(
          StateError('simulated history box open failure'),
        );
      }
      return Hive.openBox<T>(name);
    }

    final startup = startupFor(names, opener: failAtHistory);
    await expectLater(startup.open(), throwsA(isA<StateError>()));

    expect(Hive.isBoxOpen(names.templates), isFalse);
    expect(Hive.isBoxOpen(names.settings), isFalse);
    expect(Hive.isBoxOpen(names.history), isFalse);
    expect(
      await File('${tempDir.path}/${names.templates}.hive').exists(),
      isTrue,
    );

    final reopened = await Hive.openBox<Node>(names.templates);
    expect(reopened.get('keep')!.name, 'Existing data');
    expect(reopened.get('keep')!.id, 'keep-id');
    await reopened.close();
  });

  test('current Node adapter reads a record written without loggedMinutes',
      () async {
    const boxName = 'legacy_node_schema';
    await Hive.close();

    Hive.registerAdapter(_LegacyNodeAdapter(), override: true);
    final oldVersionBox = await Hive.openBox<Node>(boxName);
    await oldVersionBox.put(
      'legacy',
      Node.leaf(
        'Legacy node',
        id: 'legacy-node-id',
        trackingId: 'legacy-tracking-id',
        targetMinutes: 45,
        loggedMinutes: 120,
      ),
    );
    await oldVersionBox.close();

    // The previous adapter did not write Hive field 15 (loggedMinutes).
    Hive.registerAdapter(NodeAdapter(), override: true);
    final currentVersionBox = await Hive.openBox<Node>(boxName);
    final restored = currentVersionBox.get('legacy')!;

    expect(restored.name, 'Legacy node');
    expect(restored.id, 'legacy-node-id');
    expect(restored.trackingId, 'legacy-tracking-id');
    expect(restored.targetMinutes, 45);
    expect(restored.loggedMinutes, 0);
    await currentVersionBox.close();
  });
}

class _LegacyNodeAdapter extends NodeAdapter {
  @override
  void write(BinaryWriter writer, Node obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.children)
      ..writeByte(2)
      ..write(obj.isExpanded)
      ..writeByte(3)
      ..write(obj.plannedDate)
      ..writeByte(4)
      ..write(obj.completed)
      ..writeByte(5)
      ..write(obj.stepType)
      ..writeByte(6)
      ..write(obj.totalSteps)
      ..writeByte(7)
      ..write(obj.completedSteps)
      ..writeByte(8)
      ..write(obj.id)
      ..writeByte(9)
      ..write(obj.category)
      ..writeByte(10)
      ..write(obj.excludeFromHistory)
      ..writeByte(11)
      ..write(obj.trackingId)
      ..writeByte(12)
      ..write(obj.startMinutes)
      ..writeByte(13)
      ..write(obj.templateTarget)
      ..writeByte(14)
      ..write(obj.targetMinutes);
  }
}
