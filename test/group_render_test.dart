import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerx/cubit/editor_cubit.dart';
import 'package:powerx/models/elements.dart';
import 'package:powerx/models/presentation.dart';
import 'package:powerx/models/theme.dart';
import 'package:powerx/models/text_styles.dart';
import 'package:powerx/widgets/canvas/canvas_area.dart';
import 'package:powerx/widgets/editor_shell.dart';
import 'package:powerx/widgets/presenter/presentation_view.dart';
import 'package:powerx/widgets/presenter/presenter_view.dart';

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

  testWidgets(
    'renders grouped elements in slide show without ParentData conflicts',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: PresentationView(
            presentation: _groupedPresentation(),
            initialIndex: 0,
            onExit: () {},
            onNext: () {},
            onPrevious: () {},
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(PresentationView), findsOneWidget);
    },
  );

  testWidgets(
    'renders grouped elements in presenter view without ParentData conflicts',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: PresenterView(
            presentation: _groupedPresentation(),
            initialIndex: 0,
            onExit: () {},
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(PresenterView), findsOneWidget);
    },
  );

  testWidgets('renders nested PPTX groups without ParentData conflicts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: PresentationView(
          presentation: _nestedGroupedPresentation(),
          initialIndex: 0,
          onExit: () {},
          onNext: () {},
          onPrevious: () {},
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(PresentationView), findsOneWidget);
  });

  testWidgets(
    'renders imported-style groups in editor shell without ParentData conflicts',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cubit = EditorCubit();
      cubit.addElement(_nestedGroupElement());

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(value: cubit, child: const EditorShell()),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(EditorShell), findsOneWidget);

      await cubit.close();
    },
  );
}

Presentation _groupedPresentation() {
  return const Presentation(
    id: 'presentation-1',
    title: 'Grouped',
    theme: PresentationTheme(),
    slides: [
      Slide(
        id: 'slide-1',
        elements: [
          GroupElement(
            id: 'group-1',
            position: Offset(40, 40),
            size: Size(300, 300),
            zIndex: 0,
            children: [
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
        ],
      ),
    ],
  );
}

Presentation _nestedGroupedPresentation() {
  return const Presentation(
    id: 'presentation-2',
    title: 'Nested Grouped',
    theme: PresentationTheme(),
    slides: [
      Slide(
        id: 'slide-1',
        elements: [
          GroupElement(
            id: 'outer-group',
            position: Offset(44.2, 45.1),
            size: Size(629.9, 629.9),
            zIndex: 0,
            children: [
              GroupElement(
                id: 'inner-group',
                position: Offset(44.2, 45.1),
                size: Size(629.9, 629.9),
                zIndex: 0,
                children: [
                  ShapeElement(
                    id: 'nested-child-shape',
                    position: Offset(44.2, 45.1),
                    size: Size(320, 240),
                    zIndex: 0,
                    shapeType: ShapeType.rectangle,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

GroupElement _nestedGroupElement() {
  return const GroupElement(
    id: 'outer-group',
    position: Offset(44.2, 45.1),
    size: Size(629.9, 629.9),
    zIndex: 0,
    children: [
      GroupElement(
        id: 'inner-group',
        position: Offset(44.2, 45.1),
        size: Size(629.9, 629.9),
        zIndex: 0,
        children: [
          ShapeElement(
            id: 'nested-child-shape',
            position: Offset(44.2, 45.1),
            size: Size(320, 240),
            zIndex: 0,
            shapeType: ShapeType.rectangle,
          ),
        ],
      ),
    ],
  );
}
