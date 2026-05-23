import 'dart:math';
import 'package:flutter/material.dart';

class InkStroke {
  final String id;
  final List<InkPoint> points;
  final Color color;
  final double thickness;
  final double opacity;
  final bool isHighlighter;
  final DateTime createdAt;

  InkStroke({
    required this.id,
    required this.points,
    this.color = Colors.black,
    this.thickness = 2.0,
    this.opacity = 1.0,
    this.isHighlighter = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  InkStroke copyWith({
    List<InkPoint>? points,
    Color? color,
    double? thickness,
    double? opacity,
    bool? isHighlighter,
  }) => InkStroke(
    id: id,
    points: points ?? this.points,
    color: color ?? this.color,
    thickness: thickness ?? this.thickness,
    opacity: opacity ?? this.opacity,
    isHighlighter: isHighlighter ?? this.isHighlighter,
    createdAt: createdAt,
  );

  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    double minX = points.first.x, maxX = points.first.x;
    double minY = points.first.y, maxY = points.first.y;
    for (final p in points) {
      minX = min(minX, p.x);
      maxX = max(maxX, p.x);
      minY = min(minY, p.y);
      maxY = max(maxY, p.y);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

class InkPoint {
  final double x;
  final double y;
  final double pressure;
  final double tiltX;
  final double tiltY;
  final DateTime timestamp;

  const InkPoint({
    required this.x,
    required this.y,
    this.pressure = 1.0,
    this.tiltX = 0.0,
    this.tiltY = 0.0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? const _ConstantDateTime();

  Offset get offset => Offset(x, y);
}

class _ConstantDateTime implements DateTime {
  const _ConstantDateTime();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class InkCanvas extends StatefulWidget {
  final List<InkStroke> strokes;
  final Function(InkStroke) onStrokeComplete;
  final Function(InkStroke)? onStrokeUpdate;
  final Color currentColor;
  final double currentThickness;
  final bool isHighlighter;
  final bool isEraser;
  final double eraserSize;
  final Size canvasSize;

  const InkCanvas({
    super.key,
    required this.strokes,
    required this.onStrokeComplete,
    this.onStrokeUpdate,
    this.currentColor = Colors.black,
    this.currentThickness = 2.0,
    this.isHighlighter = false,
    this.isEraser = false,
    this.eraserSize = 20.0,
    required this.canvasSize,
  });

  @override
  State<InkCanvas> createState() => _InkCanvasState();
}

class _InkCanvasState extends State<InkCanvas> {
  InkStroke? _currentStroke;
  final List<InkStroke> _strokes = [];

  @override
  void initState() {
    super.initState();
    _strokes.addAll(widget.strokes);
  }

  @override
  void didUpdateWidget(covariant InkCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.strokes != oldWidget.strokes) {
      _strokes.clear();
      _strokes.addAll(widget.strokes);
    }
  }

  void _startStroke(Offset position, double pressure) {
    if (widget.isEraser) {
      _eraseAt(position);
      return;
    }

    _currentStroke = InkStroke(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      points: [InkPoint(x: position.dx, y: position.dy, pressure: pressure)],
      color: widget.currentColor,
      thickness: widget.currentThickness,
      isHighlighter: widget.isHighlighter,
    );
  }

  void _updateStroke(Offset position, double pressure) {
    if (widget.isEraser) {
      _eraseAt(position);
      return;
    }

    if (_currentStroke == null) return;

    setState(() {
      _currentStroke = _currentStroke!.copyWith(
        points: [..._currentStroke!.points, InkPoint(
          x: position.dx,
          y: position.dy,
          pressure: pressure,
        )],
      );
    });

    widget.onStrokeUpdate?.call(_currentStroke!);
  }

  void _endStroke() {
    if (_currentStroke != null && _currentStroke!.points.length > 1) {
      widget.onStrokeComplete(_currentStroke!);
      _strokes.add(_currentStroke!);
    }
    _currentStroke = null;
  }

  void _eraseAt(Offset position) {
    final eraseRect = Rect.fromCenter(
      center: position,
      width: widget.eraserSize,
      height: widget.eraserSize,
    );

    setState(() {
      _strokes.removeWhere((stroke) {
        if (!stroke.bounds.overlaps(eraseRect)) return false;
        return stroke.points.any((p) => eraseRect.contains(p.offset));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => _startStroke(details.localPosition, 1.0),
      onPanUpdate: (details) => _updateStroke(details.localPosition, 1.0),
      onPanEnd: (_) => _endStroke(),
      child: CustomPaint(
        size: widget.canvasSize,
        painter: _InkPainter(
          strokes: [..._strokes, ?_currentStroke],
          isEraser: widget.isEraser,
          eraserPosition: widget.isEraser ? null : null,
          eraserSize: widget.eraserSize,
        ),
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  final List<InkStroke> strokes;
  final bool isEraser;
  final Offset? eraserPosition;
  final double eraserSize;

  _InkPainter({
    required this.strokes,
    required this.isEraser,
    this.eraserPosition,
    required this.eraserSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    if (isEraser && eraserPosition != null) {
      _drawEraserCursor(canvas, eraserPosition!);
    }
  }

  void _drawStroke(Canvas canvas, InkStroke stroke) {
    if (stroke.points.length < 2) return;

    final path = Path();
    final paint = Paint()
      ..color = stroke.isHighlighter
          ? stroke.color.withOpacity(0.3)
          : stroke.color.withOpacity(stroke.opacity)
      ..strokeWidth = stroke.isHighlighter ? stroke.thickness * 3 : stroke.thickness
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.isHighlighter) {
      paint.blendMode = BlendMode.multiply;
    }

    // Smooth the path using Catmull-Rom splines
    final points = stroke.points.map((p) => p.offset).toList();
    
    if (points.length == 2) {
      path.moveTo(points[0].dx, points[0].dy);
      path.lineTo(points[1].dx, points[1].dy);
    } else {
      path.moveTo(points[0].dx, points[0].dy);
      
      for (int i = 1; i < points.length - 1; i++) {
        final p0 = points[i - 1];
        final p1 = points[i];
        final p2 = points[i + 1];
        
        final cp1x = p1.dx - (p2.dx - p0.dx) / 6;
        final cp1y = p1.dy - (p2.dy - p0.dy) / 6;
        final cp2x = p1.dx + (p2.dx - p0.dx) / 6;
        final cp2y = p1.dy + (p2.dy - p0.dy) / 6;
        
        path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
      }
    }

    // Variable width based on pressure
    if (stroke.points.any((p) => p.pressure != 1.0)) {
      _drawPressureSensitiveStroke(canvas, stroke);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void _drawPressureSensitiveStroke(Canvas canvas, InkStroke stroke) {
    for (int i = 1; i < stroke.points.length; i++) {
      final p1 = stroke.points[i - 1];
      final p2 = stroke.points[i];
      
      final avgPressure = (p1.pressure + p2.pressure) / 2;
      final width = stroke.thickness * avgPressure;
      
      final paint = Paint()
        ..color = stroke.color.withOpacity(stroke.opacity)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(p1.x, p1.y),
        Offset(p2.x, p2.y),
        paint,
      );
    }
  }

  void _drawEraserCursor(Canvas canvas, Offset position) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(position, eraserSize / 2, paint);

    final borderPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(position, eraserSize / 2, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Lasso selection for ink
class LassoSelection {
  final List<Offset> points;
  final Path path;

  LassoSelection(this.points) : path = _createPath(points);

  static Path _createPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    return path;
  }

  bool containsStroke(InkStroke stroke) {
    return stroke.points.any((p) => path.contains(p.offset));
  }

  List<InkStroke> getSelectedStrokes(List<InkStroke> allStrokes) {
    return allStrokes.where(containsStroke).toList();
  }
}

// Ink recognition (basic shape recognition)
class InkRecognizer {
  static RecognizedShape recognize(List<InkPoint> points) {
    if (points.length < 3) return RecognizedShape.unknown;

    final boundingBox = _calculateBoundingBox(points);
    final aspectRatio = boundingBox.width / boundingBox.height;
    final area = boundingBox.width * boundingBox.height;
    final pathLength = _calculatePathLength(points);
    final compactness = area / (pathLength * pathLength);

    // Circle detection
    if (aspectRatio > 0.8 && aspectRatio < 1.2 && compactness > 0.06) {
      return RecognizedShape.circle;
    }

    // Rectangle detection
    if (aspectRatio > 0.3 && aspectRatio < 3 && compactness > 0.04) {
      final cornerCount = _countCorners(points);
      if (cornerCount >= 3 && cornerCount <= 5) {
        return RecognizedShape.rectangle;
      }
    }

    // Triangle detection
    if (compactness > 0.03 && compactness < 0.06) {
      final cornerCount = _countCorners(points);
      if (cornerCount == 3) return RecognizedShape.triangle;
    }

    // Line detection
    if (compactness < 0.02 && pathLength > max(boundingBox.width, boundingBox.height) * 1.5) {
      return RecognizedShape.line;
    }

    return RecognizedShape.unknown;
  }

  static Rect _calculateBoundingBox(List<InkPoint> points) {
    double minX = points.first.x, maxX = points.first.x;
    double minY = points.first.y, maxY = points.first.y;
    for (final p in points) {
      minX = min(minX, p.x);
      maxX = max(maxX, p.x);
      minY = min(minY, p.y);
      maxY = max(maxY, p.y);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static double _calculatePathLength(List<InkPoint> points) {
    double length = 0;
    for (int i = 1; i < points.length; i++) {
      length += (points[i].offset - points[i - 1].offset).distance;
    }
    return length;
  }

  static int _countCorners(List<InkPoint> points) {
    if (points.length < 10) return 0;
    
    final corners = <int>[];
    for (int i = 5; i < points.length - 5; i++) {
      final prev = points[i - 5].offset;
      final curr = points[i].offset;
      final next = points[i + 5].offset;
      
      final v1 = curr - prev;
      final v2 = next - curr;
      
      final angle = atan2(v2.dy, v2.dx) - atan2(v1.dy, v1.dx);
      if (angle.abs() > pi / 4) {
        corners.add(i);
      }
    }
    return corners.length;
  }
}

enum RecognizedShape {
  unknown,
  line,
  rectangle,
  circle,
  triangle,
  ellipse,
  arrow,
}

// Ink toolbar
class InkToolbar extends StatelessWidget {
  final Color selectedColor;
  final double selectedThickness;
  final bool isHighlighter;
  final bool isEraser;
  final Function(Color) onColorChanged;
  final Function(double) onThicknessChanged;
  final Function(bool) onHighlighterChanged;
  final Function(bool) onEraserChanged;
  final VoidCallback onClear;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  const InkToolbar({
    super.key,
    required this.selectedColor,
    required this.selectedThickness,
    required this.isHighlighter,
    required this.isEraser,
    required this.onColorChanged,
    required this.onThicknessChanged,
    required this.onHighlighterChanged,
    required this.onEraserChanged,
    required this.onClear,
    required this.onUndo,
    required this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tools
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToolButton(Icons.edit, 'Pen', !isHighlighter && !isEraser, () {
                onHighlighterChanged(false);
                onEraserChanged(false);
              }),
              _buildToolButton(Icons.highlight, 'Highlighter', isHighlighter, () {
                onHighlighterChanged(!isHighlighter);
                onEraserChanged(false);
              }),
              _buildToolButton(Icons.auto_fix_normal, 'Eraser', isEraser, () {
                onEraserChanged(!isEraser);
                onHighlighterChanged(false);
              }),
            ],
          ),
          const Divider(),
          // Colors
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              Colors.black,
              Colors.red,
              Colors.blue,
              Colors.green,
              Colors.yellow,
              Colors.purple,
              Colors.orange,
              Colors.brown,
            ].map((color) => _buildColorButton(color)).toList(),
          ),
          const Divider(),
          // Thickness
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Size:', style: TextStyle(fontSize: 12)),
              SizedBox(
                width: 100,
                child: Slider(
                  value: selectedThickness,
                  min: 0.5,
                  max: 20,
                  onChanged: onThicknessChanged,
                ),
              ),
            ],
          ),
          const Divider(),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.undo), onPressed: onUndo),
              IconButton(icon: const Icon(Icons.redo), onPressed: onRedo),
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                onPressed: onClear,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(IconData icon, String tooltip, bool isSelected, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[100] : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 20, color: isSelected ? Colors.blue : Colors.black),
        ),
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = selectedColor == color;
    return InkWell(
      onTap: () => onColorChanged(color),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}
