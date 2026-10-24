import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/screens/components/quick_add_bar.dart';

void main() {
  Future<List<String>> pumpBar(WidgetTester tester) async {
    final added = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickAddBar(onAdd: added.add, onOpenPicker: () {}),
        ),
      ),
    );
    return added;
  }

  testWidgets('Enter adds the trimmed name and clears the field',
      (tester) async {
    final added = await pumpBar(tester);
    await tester.enterText(find.byType(TextField), '  Прогулка  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(added, ['Прогулка']);
    expect(find.text('Прогулка'), findsNothing);
  });

  testWidgets('empty or blank input adds nothing', (tester) async {
    final added = await pumpBar(tester);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    expect(added, isEmpty);
  });

  testWidgets('the send button adds too', (tester) async {
    final added = await pumpBar(tester);
    await tester.enterText(find.byType(TextField), 'Зарядка');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    expect(added, ['Зарядка']);
  });
}
