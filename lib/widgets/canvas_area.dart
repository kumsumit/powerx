import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/editor_cubit.dart';
import '../models/presentation.dart';

class CanvasArea extends StatelessWidget {
  final double zoom;
  const CanvasArea({super.key, required this.zoom});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    final slide = state.activeSlide;

    return Container(
      color: const Color(0xFFE6E6E6), // PowerPoint canvas grey
      child: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 0.1,
        maxScale: 5.0,
        scaleFactor: 500,
        onInteractionEnd: (_) {
          // Could persist zoom here
        },
        child: Center(
          child: GestureDetector(
            onTapDown: (details) {
              // If clicking empty canvas, deselect
              cubit.selectElement(null);
            },
            child: Container(
              width: 960 * zoom, // 16:9 base resolution
              height: 540 * zoom,
              color: slide.backgroundColor,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ...slide.elements.map((e) => _ElementWrapper(
                        key: ValueKey(e.id),
                        element: e,
                        isSelected: state.selectedElementId == e.id,
                      )),
                  // Ghost for adding new elements
                  if (state.activeTool != Tool.select)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: (details) {
                          _handleToolTap(context, details.localPosition, state.activeTool);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleToolTap(BuildContext context, Offset position, Tool tool) {
    final cubit = context.read<EditorCubit>();
    const uuid = Uuid();
    final id = uuid.v4();

    switch (tool) {
      case Tool.textBox:
        cubit.addElement(TextElement(
          id: id,
          position: position,
          size: const Size(200, 50),
          zIndex: cubit.state.activeSlide.elements.length,
        ));
        cubit.setTool(Tool.select);
        break;
      case Tool.rectangle:
        cubit.addElement(ShapeElement(
          id: id,
          position: position,
          size: const Size(150, 100),
          zIndex: cubit.state.activeSlide.elements.length,
        ));
        cubit.setTool(Tool.select);
        break;
      case Tool.circle:
        cubit.addElement(ShapeElement(
          id: id,
          position: position,
          size: const Size(100, 100),
          shapeType: ShapeType.circle,
          zIndex: cubit.state.activeSlide.elements.length,
        ));
        cubit.setTool(Tool.select);
        break;
      default:
        break;
    }
  }
}

class _ElementWrapper extends StatefulWidget {
  final SlideElement element;
  final bool isSelected;

  const _ElementWrapper({super.key, required this.element, required this.isSelected});

  @override
  State<_ElementWrapper> createState() => _ElementWrapperState();
}

class _ElementWrapperState extends State<_ElementWrapper> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.element;
    final cubit = context.read<EditorCubit>();

    Widget content;
    if (e is TextElement) {
      content = _isEditing && widget.isSelected
          ? TextField(
              controller: TextEditingController(text: e.text),
              autofocus: true,
              maxLines: null,
              style: e.style,
              textAlign: e.align,
              onChanged: (val) => cubit.updateElement(e.copyWith(text: val)),
              onSubmitted: (_) => setState(() => _isEditing = false),
            )
          : Text(e.text, style: e.style, textAlign: e.align);
    } else if (e is ShapeElement) {
      content = Container(
        decoration: BoxDecoration(
          color: e.fillColor,
          border: Border.all(color: e.strokeColor, width: e.strokeWidth),
          borderRadius: e.shapeType == ShapeType.circle
              ? BorderRadius.circular(e.size.width / 2)
              : null,
        ),
      );
    } else {
      content = const SizedBox();
    }

    return Positioned(
      left: e.position.dx,
      top: e.position.dy,
      width: e.size.width,
      height: e.size.height,
      child: GestureDetector(
        onTap: () {
          cubit.selectElement(e.id);
          if (e is TextElement) setState(() => _isEditing = false);
        },
        onDoubleTap: () {
          if (e is TextElement) setState(() => _isEditing = true);
        },
        onPanUpdate: widget.isSelected
            ? (details) {
                cubit.moveElement(e.id, details.delta);
              }
            : null,
        child: Transform.rotate(
          angle: e.rotation,
          child: Container(
            decoration: widget.isSelected
                ? BoxDecoration(
                    border: Border.all(color: const Color(0xFF4472C4), width: 2),
                  )
                : null,
            child: content,
          ),
        ),
      ),
    );
  }
}

// Stub for Uuid in this file if needed, otherwise import from main
class Uuid {
  const Uuid();
  String v4() => DateTime.now().millisecondsSinceEpoch.toString();
}