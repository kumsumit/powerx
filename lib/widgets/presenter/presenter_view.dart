import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/presentation.dart';
import '../../models/elements.dart';
import '../../models/table.dart' as pt;
import '../../models/chart.dart';
import '../shapes/shape_renderer.dart';
import '../tables/table_widget.dart';
import '../../engine/charts/advanced_charts.dart';

class PresenterView extends StatefulWidget {
  final Presentation presentation;
  final int initialIndex;
  final VoidCallback onExit;

  const PresenterView({
    super.key,
    required this.presentation,
    required this.initialIndex,
    required this.onExit,
  });

  @override
  State<PresenterView> createState() => _PresenterViewState();
}

class _PresenterViewState extends State<PresenterView> {
  late int currentIndex;
  late Timer _timer;
  Duration _elapsed = Duration.zero;
  bool _showTimer = true;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed += const Duration(seconds: 1);
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _next() {
    if (currentIndex < widget.presentation.slides.length - 1) {
      setState(() => currentIndex++);
    }
  }

  void _prev() {
    if (currentIndex > 0) {
      setState(() => currentIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.presentation.slides[currentIndex];
    final nextSlide = currentIndex < widget.presentation.slides.length - 1
        ? widget.presentation.slides[currentIndex + 1]
        : null;

    return RawKeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.space) {
            _next();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _prev();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onExit();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1a1a1a),
        body: Row(
          children: [
            // Left: Current slide large
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Container(
                            width: widget.presentation.settings.slideSize.width,
                            height:
                                widget.presentation.settings.slideSize.height,
                            color:
                                slide.backgroundColorOverride ?? Colors.white,
                            child: Stack(
                              children: slide.elements
                                  .map((e) => _buildElement(e))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Notes section
                  Container(
                    height: 200,
                    color: const Color(0xFF2a2a2a),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Speaker Notes',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(
                              text: slide.notes ?? '',
                            ),
                            style: const TextStyle(color: Colors.white70),
                            maxLines: null,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Add notes...',
                              hintStyle: TextStyle(color: Colors.white30),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Right: Controls and next slide
            Container(
              width: 300,
              color: const Color(0xFF2a2a2a),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timer
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a1a1a),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.timer, color: Colors.white),
                          onPressed: () =>
                              setState(() => _showTimer = !_showTimer),
                        ),
                        if (_showTimer)
                          Text(
                            '${_elapsed.inMinutes.toString().padLeft(2, '0')}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontFamily: 'monospace',
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Slide counter
                  Text(
                    'Slide ${currentIndex + 1} of ${widget.presentation.slides.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  // Next slide preview
                  const Text(
                    'Next Slide',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (nextSlide != null)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Container(
                          width: widget.presentation.settings.slideSize.width,
                          height: widget.presentation.settings.slideSize.height,
                          color:
                              nextSlide.backgroundColorOverride ?? Colors.white,
                          child: Stack(
                            children: nextSlide.elements
                                .map((e) => _buildElement(e))
                                .toList(),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 150,
                      color: const Color(0xFF1a1a1a),
                      child: const Center(
                        child: Text(
                          'End of presentation',
                          style: TextStyle(color: Colors.white30),
                        ),
                      ),
                    ),
                  const Spacer(),
                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: _prev,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                        ),
                        onPressed: _next,
                      ),
                      IconButton(
                        icon: const Icon(Icons.exit_to_app, color: Colors.red),
                        onPressed: widget.onExit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElement(SlideElement e) {
    final elementWidget = _buildElementContent(e);

    return Positioned(
      left: e.position.dx,
      top: e.position.dy,
      width: e.size.width,
      height: e.size.height,
      child: Transform.rotate(
        angle: e.rotation * pi / 180,
        child: elementWidget,
      ),
    );
  }

  /// Builds an element's visual without its outer [Positioned] wrapper, so
  /// grouped children can be positioned by their parent group's [Stack].
  Widget _buildElementContent(SlideElement e) {
    Widget elementWidget;

    if (e is TextElement) {
      elementWidget = _buildTextElement(e);
    } else if (e is ShapeElement) {
      elementWidget = ShapeRenderer(shape: e);
    } else if (e is ImageElement) {
      final imageFile = File(e.imagePath);
      elementWidget = e.imagePath.isEmpty || !imageFile.existsSync()
          ? Container(
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.image, color: Colors.grey)),
            )
          : Image.file(
              imageFile,
              fit: BoxFit.fill,
              width: e.size.width,
              height: e.size.height,
            );
    } else if (e is pt.TableElement) {
      elementWidget = TableWidget(table: e);
    } else if (e is ChartElement) {
      final rows = e.data.series.map((s) => s.values).toList();
      final dataTable = ChartDataTable(
        rowHeaders: e.data.series.map((s) => s.name).toList(),
        columnHeaders: e.data.categories,
        data: rows,
        seriesColors: e.data.series.map((s) => s.color).toList(),
      );
      elementWidget = Container(
        color: e.style.backgroundColor,
        child: AdvancedChartRenderer(
          type: _mapChartType(e.type),
          data: dataTable,
          size: e.size,
          showLegend: e.hasLegend,
          title: e.hasTitle ? e.title : null,
        ),
      );
    } else if (e is InkElement) {
      elementWidget = CustomPaint(
        size: e.size,
        painter: _InkElementPainter(
          points: e.points,
          color: e.color,
          thickness: e.thickness,
          isHighlighter: e.isHighlighter,
          opacity: e.opacity,
        ),
      );
    } else if (e is GroupElement) {
      elementWidget = Stack(
        clipBehavior: Clip.none,
        children: e.children.map((child) {
          return Positioned(
            left: child.position.dx - e.position.dx,
            top: child.position.dy - e.position.dy,
            width: child.size.width,
            height: child.size.height,
            child: Transform.rotate(
              angle: child.rotation * pi / 180,
              child: _buildElementContent(child),
            ),
          );
        }).toList(),
      );
    } else {
      elementWidget = const SizedBox();
    }

    return elementWidget;
  }

  Widget _buildTextElement(TextElement e) {
    return Container(
      color: e.fillColor,
      child: ClipRect(
        child: Padding(
          padding: e.padding,
          child: RichText(
            overflow: TextOverflow.clip,
            text: TextSpan(children: _buildTextSpans(e)),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _buildTextSpans(TextElement e) {
    final spans = <InlineSpan>[];
    for (var i = 0; i < e.paragraphs.length; i++) {
      final para = e.paragraphs[i];
      for (final run in para.runs) {
        spans.add(
          TextSpan(
            text: run.text,
            style: TextStyle(
              fontFamily: run.fontFamily,
              fontSize: run.fontSize,
              color: run.color,
              fontWeight: run.bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: run.italic ? ui.FontStyle.italic : ui.FontStyle.normal,
              decoration: run.underline
                  ? TextDecoration.underline
                  : run.strikethrough
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
          ),
        );
      }
      if (i < e.paragraphs.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    return spans;
  }

  AdvancedChartType _mapChartType(ChartType t) {
    switch (t) {
      case ChartType.bar:
        return AdvancedChartType.barClustered;
      case ChartType.line:
        return AdvancedChartType.line;
      case ChartType.pie:
        return AdvancedChartType.pie;
      default:
        return AdvancedChartType.columnClustered;
    }
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
