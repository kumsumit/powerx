import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerx/cubit/editor_cubit.dart';
import 'package:powerx/models/elements.dart';
import 'package:powerx/models/text_styles.dart';
import 'package:powerx/widgets/canvas/canvas_area.dart';

Future<EditorCubit> _pumpCanvas(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final cubit = EditorCubit();
  const id = 'txt_1';
  cubit.addElement(
    TextElement(
      id: id,
      position: const Offset(100, 100),
      size: const Size(300, 60),
      zIndex: 0,
      paragraphs: const [
        RichParagraph(runs: [TextRun(text: 'Click to edit')]),
      ],
    ),
  );
  cubit.selectElement(id);

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
  await tester.pumpAndSettle();
  return cubit;
}

// Slide (960x540) centered in 1400x900 => origin (220,180).
// Element pos (100,100) size 300x60 => slide-local handle anchors + (220,180).
const _bottomEdge = Offset(470, 340); // (100+150, 100+60) + origin
const _topEdge = Offset(470, 280); //    (100+150, 100)    + origin
const _rightEdge = Offset(620, 310); //  (100+300, 100+30) + origin
const _bottomRight = Offset(620, 340);

void main() {
  testWidgets('bottom edge: visible mid-drag and grows', (tester) async {
    final cubit = await _pumpCanvas(tester);
    final before = cubit.state.activeSlide.elements.first;

    final g = await tester.startGesture(_bottomEdge);
    // Step the drag and inspect every intermediate frame.
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(0, 10));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'mid-drag frame $i');
      expect(find.text('Click to edit', findRichText: true), findsOneWidget,
          reason: 'box vanished mid-drag at frame $i');
    }
    await g.up();
    await tester.pumpAndSettle();

    final after = cubit.state.activeSlide.elements.first;
    expect(after.size.height, greaterThan(before.size.height));
    expect(after.position, before.position);
  });

  testWidgets('top edge shrink keeps box visible', (tester) async {
    final cubit = await _pumpCanvas(tester);
    await tester.dragFrom(_topEdge, const Offset(0, 30)); // shrink from top
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Click to edit', findRichText: true), findsOneWidget);
    final after = cubit.state.activeSlide.elements.first;
    expect(after.size.height, lessThan(60));
  });

  testWidgets('right edge resizes width only', (tester) async {
    final cubit = await _pumpCanvas(tester);
    await tester.dragFrom(_rightEdge, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final after = cubit.state.activeSlide.elements.first;
    expect(after.size.width, greaterThan(300));
    expect(after.size.height, 60);
  });

  testWidgets('bottom-right corner resizes both', (tester) async {
    final cubit = await _pumpCanvas(tester);
    await tester.dragFrom(_bottomRight, const Offset(40, 40));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final after = cubit.state.activeSlide.elements.first;
    expect(after.size.width, greaterThan(300));
    expect(after.size.height, greaterThan(60));
  });

  testWidgets('mouse press-pause-drag on edge keeps selection and resizes', (
    tester,
  ) async {
    final cubit = await _pumpCanvas(tester);
    expect(cubit.state.selectedElementId, 'txt_1');

    // Real mouse: press, hold past the tap deadline, THEN drag.
    final g = await tester.startGesture(
      _bottomEdge,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 250)); // exceed kPressTimeout
    expect(
      cubit.state.selectedElementId,
      'txt_1',
      reason: 'box was deselected just by pressing near the edge',
    );

    for (var i = 0; i < 6; i++) {
      await g.moveBy(const Offset(0, 10));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();

    expect(cubit.state.selectedElementId, 'txt_1');
    expect(cubit.state.activeSlide.elements.first.size.height, greaterThan(60));
  });
}
