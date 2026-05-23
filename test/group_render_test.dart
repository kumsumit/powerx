import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerx/cubit/editor_cubit.dart';
import 'package:powerx/models/elements.dart';
import 'package:powerx/models/text_styles.dart';
import 'package:powerx/widgets/canvas/canvas_area.dart';

void main() {
  testWidgets('renders a grouped element without ParentData conflicts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final cubit = EditorCubit();
    // A group whose children carry absolute slide coordinates, exactly as the
    // importer produces them from a <p:grpSp>.
    cubit.addElement(
      GroupElement(
        id: 'group-1',
        position: const Offset(40, 40),
        size: const Size(300, 300),
        zIndex: 0,
        children: const [
          ShapeElement(
            id: 'child-shape',
            position: Offset(40, 40),
            size: Size(80, 80),
            zIndex: 0,
            shapeType: ShapeType.rectangle,
          ),
          TextElement(
            id: 'child-text',
            position: Offset(160, 160),
            size: Size(160, 120),
            zIndex: 1,
            paragraphs: [
              RichParagraph(runs: [TextRun(text: 'Grouped')]),
            ],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const CanvasArea(zoom: 1.0),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CanvasArea), findsOneWidget);

    await cubit.close();
  });
}
