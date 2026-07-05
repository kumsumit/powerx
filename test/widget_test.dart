import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerx/powerx.dart';

void main() {
  testWidgets('PowerXEditor loads editor shell successfully', (
    WidgetTester tester,
  ) async {
    // Set a landscape orientation constraint matching landscape design
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(home: PowerXEditor()));

    // Verify that the editor shell loads.
    expect(find.byType(EditorShell), findsOneWidget);
    expect(find.text('Slide 1 of 1'), findsOneWidget);
  });
}
