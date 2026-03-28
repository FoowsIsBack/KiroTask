// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/main.dart';
void main() {
  testWidgets('ToDoApp loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ToDoApp());

    // Verify that the app bar title is shown.
    expect(find.text('To Do List with Calendar'), findsOneWidget);

    // Verify that the "Add" button is present.
    expect(find.text('Add'), findsOneWidget);

    // Verify that the text field hint is present.
    expect(find.text('Add a new task...'), findsOneWidget);
  });
}
