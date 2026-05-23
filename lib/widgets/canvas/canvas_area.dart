import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubit/editor_cubit.dart';
import '../../models/elements.dart';
import '../../models/table.dart';
import '../../models/chart.dart';
import '../../models/text_styles.dart';
import '../text/rich_text_editor.dart';
import '../shapes/shape_renderer.dart';
import '../tables/table_widget.dart';
import '../shapes/selection_handles.dart';

class CanvasArea extends StatelessWidget {
  final double zoom;
  const CanvasArea({super.key, required this.zoom});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorCubit>().state;
    final slide = state.activeSlide;
    final settings = state.presentation.settings;

    return Container(
      color: const Color(0xFF808080),
      child: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(200),
        minScale: 0.1,
        maxScale: 5.0,
        scaleFactor: 800,
        child: Center(
          child: GestureDetector(
            onTapDown: (details) {
              final box = context.findRenderObject() as RenderBox;
              final localPos = box.globalToLocal(details.globalPosition);
              _handleCanvasTap(context, localPos, state.activeTool);
            },
            child: Container(
              width: settings.slideSize.width,
              height: settings.slideSize.height,
              color: slide.backgroundColorOverride ?? const Color(0xFFFFFFFF),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ...slide.elements.map(
                    (e) => _ElementRenderer(
                      key: ValueKey(e.id),
                      element: e,
                      isSelected: state.selectedElementId == e.id,
                      isMultiSelected: state.multiSelectedIds.contains(e.id),
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

  void _handleCanvasTap(BuildContext context, Offset position, Tool tool) {
    final cubit = context.read<EditorCubit>();
    final uuid = DateTime.now().millisecondsSinceEpoch.toString();

    switch (tool) {
      case Tool.textBox:
        cubit.addElement(
          TextElement(
            id: 'text_$uuid',
            position: position,
            size: const Size(300, 60),
            zIndex: cubit.state.activeSlide.elements.length,
            paragraphs: const [
              RichParagraph(runs: [TextRun(text: 'Click to edit')]),
            ],
          ),
        );
        cubit.setTool(Tool.select);
        break;
      case Tool.rectangle:
        cubit.addElement(
          ShapeElement(
            id: 'shape_$uuid',
            position: position,
            size: const Size(200, 150),
            zIndex: cubit.state.activeSlide.elements.length,
            shapeType: ShapeType.rectangle,
          ),
        );
        cubit.setTool(Tool.select);
        break;
      case Tool.circle:
        cubit.addElement(
          ShapeElement(
            id: 'shape_$uuid',
            position: position,
            size: const Size(150, 150),
            zIndex: cubit.state.activeSlide.elements.length,
            shapeType: ShapeType.circle,
          ),
        );
        cubit.setTool(Tool.select);
        break;
      case Tool.triangle:
        cubit.addElement(
          ShapeElement(
            id: 'shape_$uuid',
            position: position,
            size: const Size(150, 150),
            zIndex: cubit.state.activeSlide.elements.length,
            shapeType: ShapeType.triangle,
          ),
        );
        cubit.setTool(Tool.select);
        break;
      case Tool.star:
        cubit.addElement(
          ShapeElement(
            id: 'shape_$uuid',
            position: position,
            size: const Size(150, 150),
            zIndex: cubit.state.activeSlide.elements.length,
            shapeType: ShapeType.star,
          ),
        );
        cubit.setTool(Tool.select);
        break;
      case Tool.arrow:
        cubit.addElement(
          ShapeElement(
            id: 'shape_$uuid',
            position: position,
            size: const Size(200, 60),
            zIndex: cubit.state.activeSlide.elements.length,
            shapeType: ShapeType.arrow,
          ),
        );
        cubit.setTool(Tool.select);
        break;
      default:
        cubit.selectElement(null);
        break;
    }
  }
}

class _ElementRenderer extends StatelessWidget {
  final SlideElement element;
  final bool isSelected;
  final bool isMultiSelected;

  const _ElementRenderer({
    super.key,
    required this.element,
    required this.isSelected,
    required this.isMultiSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();

    Widget content;
    if (element is TextElement) {
      content = _TextElementRenderer(
        element: element as TextElement,
        isSelected: isSelected,
      );
    } else if (element is ShapeElement) {
      content = ShapeRenderer(shape: element as ShapeElement);
    } else if (element is ImageElement) {
      content = _ImageElementRenderer(element: element as ImageElement);
    } else if (element is TableElement) {
      content = TableWidget(table: element as TableElement);
    } else if (element is ChartElement) {
      content = _ChartPlaceholder(element: element as ChartElement);
    } else if (element is GroupElement) {
      content = _GroupElementRenderer(element: element as GroupElement);
    } else {
      content = const SizedBox();
    }

    return Positioned(
      left: element.position.dx,
      top: element.position.dy,
      width: element.size.width,
      height: element.size.height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => cubit.selectElement(element.id),
        onPanUpdate: isSelected && !element.isLocked
            ? (details) => cubit.moveElement(element.id, details.delta)
            : null,
        child: Transform.rotate(
          angle: element.rotation * pi / 180,
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              content,
              if (isSelected)
                Positioned.fill(
                  child: SelectionHandles(
                    element: element,
                    onResize: (newSize, newPos) => cubit.resizeElement(
                      element.id,
                      newSize,
                      newPosition: newPos,
                    ),
                  ),
                ),
              if (isSelected || isMultiSelected)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF4472C4)
                            : const Color(0xFFFFA500),
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextElementRenderer extends StatefulWidget {
  final TextElement element;
  final bool isSelected;
  const _TextElementRenderer({required this.element, required this.isSelected});

  @override
  State<_TextElementRenderer> createState() => _TextElementRendererState();
}

class _TextElementRendererState extends State<_TextElementRenderer> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();

    if (_isEditing && widget.isSelected) {
      return Container(
        color: widget.element.fillColor ?? Colors.transparent,
        padding: widget.element.padding,
        child: RichTextEditor(
          paragraphs: widget.element.paragraphs,
          onChanged: (paragraphs) =>
              cubit.updateTextElement(widget.element.id, paragraphs),
          onDone: () => setState(() => _isEditing = false),
        ),
      );
    }

    return GestureDetector(
      onDoubleTap: widget.isSelected
          ? () => setState(() => _isEditing = true)
          : null,
      child: Container(
        color: widget.element.fillColor,
        padding: widget.element.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: widget.element.paragraphs.map((para) {
            return RichText(
              text: TextSpan(
                children: para.runs.map((run) {
                  return TextSpan(
                    text: run.text,
                    style: TextStyle(
                      fontFamily: run.fontFamily,
                      fontSize: run.fontSize,
                      color: run.color,
                      fontWeight: run.bold
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontStyle: run.italic
                          ? FontStyle.italic
                          : FontStyle.normal,
                      decoration: run.underline
                          ? TextDecoration.underline
                          : run.strikethrough
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ImageElementRenderer extends StatelessWidget {
  final ImageElement element;
  const _ImageElementRenderer({required this.element});

  @override
  Widget build(BuildContext context) {
    if (element.imagePath.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: const Center(child: Icon(Icons.image, color: Colors.grey)),
      );
    }
    return Image.file(
      File(element.imagePath),
      fit: _mapFillMode(element.fillMode),
      width: element.size.width,
      height: element.size.height,
    );
  }

  BoxFit _mapFillMode(ImageFillMode mode) {
    switch (mode) {
      case ImageFillMode.stretch:
        return BoxFit.fill;
      case ImageFillMode.fit:
        return BoxFit.contain;
      case ImageFillMode.fill:
        return BoxFit.cover;
      case ImageFillMode.tile:
        return BoxFit.none;
      case ImageFillMode.center:
        return BoxFit.none;
    }
  }
}

class _ChartPlaceholder extends StatelessWidget {
  final ChartElement element;
  const _ChartPlaceholder({required this.element});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: element.style.backgroundColor,
      child: CustomPaint(
        size: element.size,
        painter: _ChartPainter(element: element),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final ChartElement element;
  _ChartPainter({required this.element});

  @override
  void paint(Canvas canvas, Size size) {
    final data = element.data;
    if (data.series.isEmpty) return;

    final paint = Paint()..strokeWidth = 2;
    final maxVal = data.series
        .expand((s) => s.values)
        .reduce((a, b) => a > b ? a : b);
    final barWidth =
        size.width /
        (data.categories.length * data.series.length +
            data.categories.length +
            1);

    for (int i = 0; i < data.categories.length; i++) {
      for (int j = 0; j < data.series.length; j++) {
        final value = data.series[j].values[i];
        final barHeight = (value / maxVal) * size.height * 0.8;
        final x = (i * (data.series.length + 1) + j + 1) * barWidth;
        final y = size.height - barHeight;

        paint.color = data.series[j].color;
        canvas.drawRect(Rect.fromLTWH(x, y, barWidth * 0.9, barHeight), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GroupElementRenderer extends StatelessWidget {
  final GroupElement element;
  const _GroupElementRenderer({required this.element});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: element.children.map((child) {
        return Positioned(
          left: child.position.dx - element.position.dx,
          top: child.position.dy - element.position.dy,
          width: child.size.width,
          height: child.size.height,
          child: _ElementRenderer(
            element: child,
            isSelected: false,
            isMultiSelected: false,
          ),
        );
      }).toList(),
    );
  }
}
