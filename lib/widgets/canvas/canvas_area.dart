import 'dart:io';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../cubit/editor_cubit.dart';
import '../../models/elements.dart';
import '../../models/table.dart';
import '../../models/chart.dart';
import '../../models/text_styles.dart';
import '../text/rich_text_editor.dart';
import '../shapes/shape_renderer.dart';
import '../tables/table_widget.dart';
import '../shapes/selection_handles.dart';
import '../../engine/charts/advanced_charts.dart';
import '../ink/ink_canvas.dart';

const _uuid = Uuid();

class CanvasArea extends StatefulWidget {
  final double zoom;
  const CanvasArea({super.key, required this.zoom});

  @override
  State<CanvasArea> createState() => _CanvasAreaState();
}

class _CanvasAreaState extends State<CanvasArea> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    final slide = state.activeSlide;
    final settings = state.presentation.settings;
    final slideSize = settings.slideSize;
    final scaledSlideSize = slideSize * widget.zoom;
    const workspacePadding = 48.0;

    return Container(
      color: const Color(0xFF808080),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = scaledSlideSize.width + workspacePadding * 2;
          final contentHeight = scaledSlideSize.height + workspacePadding * 2;

          // Disable drag-to-scroll so dragging an element/resize handle is not
          // stolen by the scroll views' (smaller-slop) drag recognizers. The
          // mouse wheel, trackpad, and scrollbar thumbs still scroll the canvas.
          final scrollBehavior = ScrollConfiguration.of(
            context,
          ).copyWith(dragDevices: const <PointerDeviceKind>{});

          return ScrollConfiguration(
            behavior: scrollBehavior,
            child: Scrollbar(
              controller: _verticalController,
              thumbVisibility: true,
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _verticalController,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: max(constraints.maxWidth, contentWidth),
                      height: max(constraints.maxHeight, contentHeight),
                      child: Center(
                        child: SizedBox(
                          width: scaledSlideSize.width,
                          height: scaledSlideSize.height,
                          child: Transform.scale(
                            scale: widget.zoom,
                            alignment: Alignment.topLeft,
                            child: GestureDetector(
                              // onTapUp (not onTapDown) so this only fires for a
                              // clean tap that wins the gesture arena. A press
                              // that turns into a drag (moving or resizing an
                              // element) lets the element's pan recognizer win,
                              // so the canvas never deselects mid-drag.
                              onTapUp: (details) {
                                _handleCanvasTap(
                                  context,
                                  details.localPosition,
                                  state.activeTool,
                                );
                              },
                              child: Container(
                                width: slideSize.width,
                                height: slideSize.height,
                                color:
                                    slide.backgroundColorOverride ??
                                    const Color(0xFFFFFFFF),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ...slide.elements.map(
                                      (e) => _ElementRenderer(
                                        key: ValueKey(e.id),
                                        element: e,
                                        zoom: widget.zoom,
                                        isSelected:
                                            state.selectedElementId == e.id,
                                        isMultiSelected: state.multiSelectedIds
                                            .contains(e.id),
                                      ),
                                    ),
                                    if (state.activeTool == Tool.pen)
                                      Positioned.fill(
                                        child: InkCanvas(
                                          strokes: const [],
                                          canvasSize: slideSize,
                                          onStrokeComplete: (stroke) {
                                            final bounds = stroke.bounds;
                                            if (bounds.width < 2 &&
                                                bounds.height < 2) {
                                              return;
                                            }
                                            final localPoints = stroke.points
                                                .map(
                                                  (p) => Offset(
                                                    p.x - bounds.left,
                                                    p.y - bounds.top,
                                                  ),
                                                )
                                                .toList();
                                            final inkEl = InkElement(
                                              id: stroke.id,
                                              position: bounds.topLeft,
                                              size: bounds.size,
                                              zIndex: slide.elements.length,
                                              points: localPoints,
                                              color: stroke.color,
                                              thickness: stroke.thickness,
                                              isHighlighter:
                                                  stroke.isHighlighter,
                                            );
                                            cubit.addElement(inkEl);
                                            cubit.setTool(Tool.select);
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleCanvasTap(BuildContext context, Offset position, Tool tool) {
    final cubit = context.read<EditorCubit>();

    switch (tool) {
      case Tool.textBox:
        cubit.addElement(
          TextElement(
            id: _uuid.v4(),
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
            id: _uuid.v4(),
            position: position,
            size: const Size(200, 150),
            zIndex: cubit.state.activeSlide.elements.length,
            shapeType: ShapeType.rectangle,
          ),
        );
        cubit.setTool(Tool.select);
        break;
      case Tool.roundedRectangle:
        cubit.addElement(
          ShapeElement(
            id: _uuid.v4(),
            position: position,
            size: const Size(200, 150),
            zIndex: cubit.state.activeSlide.elements.length,
            shapeType: ShapeType.roundedRectangle,
            cornerRadius: 16,
          ),
        );
        cubit.setTool(Tool.select);
        break;
      case Tool.diamond:
        cubit.addElement(
          ShapeElement(
            id: _uuid.v4(),
            position: position,
            size: const Size(150, 150),
            zIndex: cubit.state.activeSlide.elements.length,
            shapeType: ShapeType.diamond,
          ),
        );
        cubit.setTool(Tool.select);
        break;
      case Tool.circle:
        cubit.addElement(
          ShapeElement(
            id: _uuid.v4(),
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
            id: _uuid.v4(),
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
            id: _uuid.v4(),
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
            id: _uuid.v4(),
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

class _ElementRenderer extends StatefulWidget {
  final SlideElement element;
  final double zoom;
  final bool isSelected;
  final bool isMultiSelected;

  const _ElementRenderer({
    super.key,
    required this.element,
    required this.zoom,
    required this.isSelected,
    required this.isMultiSelected,
  });

  @override
  State<_ElementRenderer> createState() => _ElementRendererState();
}

class _ElementRendererState extends State<_ElementRenderer> {
  static const double _interactionPadding = 40.0;
  static const double _moveInset = 14.0;
  bool _isEditing = false;

  @override
  void didUpdateWidget(_ElementRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isSelected && _isEditing) {
      setState(() => _isEditing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    final element = widget.element;

    Widget content;
    if (element is TextElement) {
      content = _isEditing
          ? _buildTextEditor(element, cubit)
          : _buildTextDisplay(element);
    } else if (element is ShapeElement) {
      content = ShapeRenderer(shape: element);
    } else if (element is ImageElement) {
      content = _ImageElementRenderer(element: element);
    } else if (element is TableElement) {
      content = TableWidget(table: element);
    } else if (element is ChartElement) {
      content = _ChartPlaceholder(element: element);
    } else if (element is GroupElement) {
      content = _GroupElementRenderer(element: element);
    } else if (element is InkElement) {
      content = _InkElementRenderer(element: element);
    } else {
      content = const SizedBox();
    }

    final interactionPadding = (widget.isSelected && !_isEditing)
        ? _interactionPadding / widget.zoom
        : 0.0;
    final moveInset = _moveInset / widget.zoom;

    return Positioned(
      left: element.position.dx - interactionPadding,
      top: element.position.dy - interactionPadding,
      width: element.size.width + interactionPadding * 2,
      height: element.size.height + interactionPadding * 2,
      child: Transform.rotate(
        angle: element.rotation * pi / 180,
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: interactionPadding,
              top: interactionPadding,
              width: element.size.width,
              height: element.size.height,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (!widget.isSelected) {
                    cubit.selectElement(element.id);
                  }
                },
                onDoubleTap: () {
                  if (element is TextElement && !_isEditing) {
                    if (!widget.isSelected) {
                      cubit.selectElement(element.id);
                    }
                    setState(() => _isEditing = true);
                  }
                },
                onPanStart:
                    !widget.isSelected && !element.isLocked && !_isEditing
                    ? (_) => cubit.selectElement(element.id)
                    : null,
                onPanUpdate:
                    !widget.isSelected && !element.isLocked && !_isEditing
                    ? (details) {
                        // delta is already in unscaled slide coords (inside Transform.scale).
                        cubit.moveElement(element.id, details.delta);
                      }
                    : null,
                child: content,
              ),
            ),
            if (widget.isSelected && !_isEditing && !element.isLocked)
              Positioned(
                left: interactionPadding + moveInset,
                top: interactionPadding + moveInset,
                width: max(0, element.size.width - moveInset * 2),
                height: max(0, element.size.height - moveInset * 2),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () {
                    if (element is TextElement) {
                      setState(() => _isEditing = true);
                    }
                  },
                  onPanUpdate: (details) {
                    // delta is already in unscaled slide coords (inside Transform.scale).
                    cubit.moveElement(element.id, details.delta);
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            if (widget.isSelected && !_isEditing)
              Positioned.fill(
                child: SelectionHandles(
                  element: element,
                  zoom: widget.zoom,
                  overlayOffset: Offset(interactionPadding, interactionPadding),
                  onResize: (newSize, newPos) => cubit.resizeElement(
                    element.id,
                    newSize,
                    newPosition: newPos,
                  ),
                  onRotate: (newRotation) =>
                      cubit.rotateElement(element.id, newRotation),
                ),
              ),
            if (widget.isSelected || widget.isMultiSelected)
              Positioned(
                left: interactionPadding,
                top: interactionPadding,
                width: element.size.width,
                height: element.size.height,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: widget.isSelected
                            ? const Color(0xFF4472C4)
                            : const Color(0xFFFFA500),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextEditor(TextElement element, EditorCubit cubit) {
    return Container(
      color: element.fillColor ?? Colors.transparent,
      padding: element.padding,
      child: RichTextEditor(
        paragraphs: element.paragraphs,
        onChanged: (paragraphs) =>
            cubit.updateTextElement(element.id, paragraphs),
        onDone: () => setState(() => _isEditing = false),
      ),
    );
  }

  Widget _buildTextDisplay(TextElement element) {
    return Container(
      color: element.fillColor,
      padding: element.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: element.paragraphs.map((para) {
          return RichText(
            text: TextSpan(
              children: para.runs.map((run) {
                return TextSpan(
                  text: run.text,
                  style: TextStyle(
                    fontFamily: run.fontFamily,
                    fontSize: run.fontSize,
                    color: run.color,
                    fontWeight: run.bold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
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
    );
  }
}

class _ImageElementRenderer extends StatelessWidget {
  final ImageElement element;
  const _ImageElementRenderer({required this.element});

  @override
  Widget build(BuildContext context) {
    final imageFile = File(element.imagePath);
    if (element.imagePath.isEmpty || !imageFile.existsSync()) {
      return _ImagePlaceholder(
        width: element.size.width,
        height: element.size.height,
      );
    }
    return Image.file(
      imageFile,
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

class _ImagePlaceholder extends StatelessWidget {
  final double? width;
  final double? height;

  const _ImagePlaceholder({this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Center(child: Icon(Icons.image, color: Colors.grey)),
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  final ChartElement element;
  const _ChartPlaceholder({required this.element});

  AdvancedChartType _mapType(ChartType t) {
    switch (t) {
      case ChartType.bar:
        return AdvancedChartType.barClustered;
      case ChartType.line:
        return AdvancedChartType.line;
      case ChartType.pie:
        return AdvancedChartType.pie;
      case ChartType.area:
        return AdvancedChartType.area;
      case ChartType.scatter:
        return AdvancedChartType.scatter;
      case ChartType.radar:
        return AdvancedChartType.radar;
      default:
        return AdvancedChartType.columnClustered;
    }
  }

  ChartDataTable _toDataTable(ChartData data) {
    final rows = data.series.map((s) => s.values).toList();
    return ChartDataTable(
      rowHeaders: data.series.map((s) => s.name).toList(),
      columnHeaders: data.categories,
      data: rows,
      seriesColors: data.series.map((s) => s.color).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataTable = _toDataTable(element.data);
    if (dataTable.data.isEmpty || dataTable.columnHeaders.isEmpty) {
      return Container(
        color: element.style.backgroundColor,
        child: const Center(
          child: Icon(Icons.bar_chart, color: Colors.grey, size: 48),
        ),
      );
    }
    return Container(
      color: element.style.backgroundColor,
      child: AdvancedChartRenderer(
        type: _mapType(element.type),
        data: dataTable,
        size: element.size,
        showLegend: element.hasLegend,
        title: element.hasTitle ? element.title : null,
      ),
    );
  }
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
            zoom: 1,
            isSelected: false,
            isMultiSelected: false,
          ),
        );
      }).toList(),
    );
  }
}

class _InkElementRenderer extends StatelessWidget {
  final InkElement element;
  const _InkElementRenderer({required this.element});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: element.size,
      painter: _InkElementPainter(
        points: element.points,
        color: element.color,
        thickness: element.thickness,
        isHighlighter: element.isHighlighter,
        opacity: element.opacity,
      ),
    );
  }
}

class _InkElementPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double thickness;
  final bool isHighlighter;
  final double opacity;

  _InkElementPainter({
    required this.points,
    required this.color,
    required this.thickness,
    required this.isHighlighter,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = isHighlighter
          ? color.withOpacity(0.3)
          : color.withOpacity(opacity)
      ..strokeWidth = isHighlighter ? thickness * 3 : thickness
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (isHighlighter) {
      paint.blendMode = BlendMode.multiply;
    }

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
