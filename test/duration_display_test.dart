import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/models/node.dart';
import 'package:book_tracker/utils/format_minutes.dart';
import 'package:book_tracker/widgets/node_tile.dart';

Widget host(Node node) => MaterialApp(
      home: Scaffold(
        body: NodeTile(node: node, depth: 0, bookId: 'b', onTap: () {}),
      ),
    );

void main() {
  group('durationProgressLabel', () {
    test('without a goal shows only logged time', () {
      expect(durationProgressLabel(25, null), '25 мин');
      expect(durationProgressLabel(25, 0), '25 мин');
      expect(durationProgressLabel(0, null), '0 мин');
    });

    test('with a goal shows logged / target time', () {
      expect(durationProgressLabel(25, 60), '25 мин / 1 ч');
      expect(durationProgressLabel(90, 90), '1 ч 30 мин / 1 ч 30 мин');
    });
  });

  group('NodeTile with independent time', () {
    testWidgets('checkbox task shows checkbox progress and time goal',
        (tester) async {
      final task = Node.leaf('Йога', targetMinutes: 60)..loggedMinutes = 25;
      await tester.pumpWidget(host(task));
      expect(find.text('Йога'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('25 мин / 1 ч'), findsOneWidget);
      expect(find.byIcon(Icons.timer), findsNothing);
    });

    testWidgets('step task shows step progress and time goal',
        (tester) async {
      final task = Node.leaf(
        'Чтение',
        stepType: 'stepByStep',
        totalSteps: 4,
        targetMinutes: 90,
      )
        ..completedSteps = 2
        ..loggedMinutes = 30;
      await tester.pumpWidget(host(task));
      expect(find.text('Чтение'), findsOneWidget);
      expect(find.text('2/4'), findsOneWidget);
      expect(find.text('30 мин / 1 ч 30 мин'), findsOneWidget);
    });

    testWidgets('task without goal does not show an empty time label',
        (tester) async {
      await tester.pumpWidget(host(Node.leaf('Прогулка')));
      expect(find.text('0 мин'), findsNothing);
    });

    testWidgets('parent task shows its time separately from child progress',
        (tester) async {
      final task = Node(
        name: 'Практика',
        stepType: 'single',
        targetMinutes: 60,
        loggedMinutes: 25,
        children: [Node.leaf('Подзадача')],
      );
      await tester.pumpWidget(host(task));
      expect(find.text('Практика'), findsOneWidget);
      expect(find.text('25 мин / 1 ч'), findsOneWidget);
      expect(find.text('0/2'), findsOneWidget);
    });
  });
}
