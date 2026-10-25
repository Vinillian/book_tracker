import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/format_minutes.dart';
import 'package:book_tracker/widgets/node_tile.dart';

Widget host(Node n) => MaterialApp(
      home: Scaffold(
        body: NodeTile(node: n, depth: 0, bookId: 'b', onTap: () {}),
      ),
    );

Node duration({int? target, int logged = 0, List<Node>? children}) => Node(
      name: 'Работа',
      children: children ?? [],
      stepType: 'duration',
      targetMinutes: target,
      loggedMinutes: logged,
    );

void main() {
  group('durationProgressLabel', () {
    test('without a goal shows only the logged time', () {
      expect(durationProgressLabel(25, null), '25 мин');
      expect(durationProgressLabel(25, 0), '25 мин');
      expect(durationProgressLabel(0, null), '0 мин');
    });

    test('with a goal shows logged / goal', () {
      expect(durationProgressLabel(25, 60), '25 мин / 1 ч');
      expect(durationProgressLabel(90, 90), '1 ч 30 мин / 1 ч 30 мин');
    });
  });

  group('NodeTile with a duration task', () {
    testWidgets('leaf with a goal shows progress and a timer icon',
        (tester) async {
      await tester.pumpWidget(host(duration(target: 60, logged: 25)));
      expect(find.text('Работа'), findsOneWidget);
      expect(find.text('25 мин / 1 ч'), findsOneWidget);
      expect(find.byIcon(Icons.timer), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('leaf without a goal shows only the logged time',
        (tester) async {
      await tester.pumpWidget(host(duration(logged: 25)));
      expect(find.text('25 мин'), findsOneWidget);
    });

    testWidgets('a task with subtasks shows its own time as the subtitle',
        (tester) async {
      await tester.pumpWidget(host(
        duration(target: 60, logged: 25, children: [Node.leaf('Подзадача')]),
      ));
      expect(find.text('25 мин / 1 ч'), findsOneWidget);
    });
  });
}
