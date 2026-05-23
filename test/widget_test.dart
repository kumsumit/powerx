import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerx/main.dart';
import 'package:powerx/widgets/editor_shell.dart';

void main() {
  testWidgets('PowerPointApp loads editor shell successfully', (WidgetTester tester) async {
    // Set a landscape orientation constraint matching landscape design
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;

    // Build our app and trigger a frame.
    await tester.pumpWidget(const PowerPointApp());

    // Verify that the editor shell loads.
    expect(find.byType(EditorShell), findsOneWidget);
    expect(find.text('Slide 1 of 1'), findsOneWidget);
  });
}
