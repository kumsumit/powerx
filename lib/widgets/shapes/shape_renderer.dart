import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/elements.dart';

class ShapeRenderer extends StatelessWidget {
  final ShapeElement shape;
  const ShapeRenderer({super.key, required this.shape});

  @override
  Widget build(BuildContext context) {
    Widget content;

    switch (shape.shapeType) {
      case ShapeType.rectangle:
        content = _buildRect();
        break;
      case ShapeType.roundedRectangle:
        content = _buildRoundedRect();
        break;
      case ShapeType.circle:
        content = _buildCircle();
        break;
      case ShapeType.triangle:
        content = _buildTriangle();
        break;
      case ShapeType.diamond:
        content = _buildDiamond();
        break;
      case ShapeType.pentagon:
        content = _buildPolygon(5);
        break;
      case ShapeType.hexagon:
        content = _buildPolygon(6);
        break;
      case ShapeType.star:
        content = _buildStar();
        break;
      case ShapeType.arrow:
        content = _buildArrow();
        break;
      default:
        content = _buildRect();
    }

    if (shape.flipHorizontal || shape.flipVertical) {
      content = Transform(
        transform: Matrix4.diagonal3Values(
          shape.flipHorizontal ? -1.0 : 1.0,
          shape.flipVertical ? -1.0 : 1.0,
          1.0,
        ),
        alignment: Alignment.center,
        child: content,
      );
    }

    return content;
  }

  Widget _buildRect() {
    return Container(
      decoration: BoxDecoration(
        color: shape.fillColor,
        gradient: shape.gradientStart != null && shape.gradientEnd != null
            ? LinearGradient(
                colors: [shape.gradientStart!, shape.gradientEnd!],
              )
            : null,
        border: shape.strokeWidth > 0
            ? Border.all(color: shape.strokeColor, width: shape.strokeWidth)
            : null,
        boxShadow: shape.shadow != null
            ? [
                BoxShadow(
                  color: shape.shadow!.color,
                  offset: Offset(shape.shadow!.offset.dx, shape.shadow!.offset.dy),
                  blurRadius: shape.shadow!.blurRadius,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildRoundedRect() {
    return Container(
      decoration: BoxDecoration(
        color: shape.fillColor,
        borderRadius: BorderRadius.circular(shape.cornerRadius ?? min(shape.size.width, shape.size.height) * 0.1),
        border: shape.strokeWidth > 0
            ? Border.all(color: shape.strokeColor, width: shape.strokeWidth)
            : null,
      ),
    );
  }

  Widget _buildCircle() {
    return Container(
      decoration: BoxDecoration(
        color: shape.fillColor,
        shape: BoxShape.circle,
        border: shape.strokeWidth > 0
            ? Border.all(color: shape.strokeColor, width: shape.strokeWidth)
            : null,
      ),
    );
  }

  Widget _buildTriangle() {
    return CustomPaint(
      size: shape.size,
      painter: _PolygonPainter(
        sides: 3,
        color: shape.fillColor,
        strokeColor: shape.strokeColor,
        strokeWidth: shape.strokeWidth,
      ),
    );
  }

  Widget _buildDiamond() {
    return Transform.rotate(
      angle: pi / 4,
      child: Container(
        width: shape.size.width * 0.7,
        height: shape.size.height * 0.7,
        decoration: BoxDecoration(
          color: shape.fillColor,
          border: shape.strokeWidth > 0
              ? Border.all(color: shape.strokeColor, width: shape.strokeWidth)
              : null,
        ),
      ),
    );
  }

  Widget _buildPolygon(int sides) {
    return CustomPaint(
      size: shape.size,
      painter: _PolygonPainter(
        sides: sides,
        color: shape.fillColor,
        strokeColor: shape.strokeColor,
        strokeWidth: shape.strokeWidth,
      ),
    );
  }

  Widget _buildStar() {
    return CustomPaint(
      size: shape.size,
      painter: _StarPainter(
        color: shape.fillColor,
        strokeColor: shape.strokeColor,
        strokeWidth: shape.strokeWidth,
      ),
    );
  }

  Widget _buildArrow() {
    return CustomPaint(
      size: shape.size,
      painter: _ArrowPainter(
        color: shape.fillColor,
        strokeColor: shape.strokeColor,
        strokeWidth: shape.strokeWidth,
      ),
    );
  }
}

class _PolygonPainter extends CustomPainter {
  final int sides;
  final Color color;
  final Color strokeColor;
  final double strokeWidth;

  _PolygonPainter({
    required this.sides,
    required this.color,
    required this.strokeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    for (int i = 0; i < sides; i++) {
      final angle = (2 * pi * i / sides) - pi / 2;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);

    if (strokeWidth > 0) {
      final strokePaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _StarPainter extends CustomPainter {
  final Color color;
  final Color strokeColor;
  final double strokeWidth;

  _StarPainter({required this.color, required this.strokeColor, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = min(size.width, size.height) / 2;
    final innerRadius = outerRadius * 0.4;

    for (int i = 0; i < 10; i++) {
      final angle = (pi * i / 5) - pi / 2;
      final radius = i.isEven ? outerRadius : innerRadius;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);

    if (strokeWidth > 0) {
      final strokePaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ArrowPainter extends CustomPainter {
  final Color color;
  final Color strokeColor;
  final double strokeWidth;

  _ArrowPainter({required this.color, required this.strokeColor, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();

    final w = size.width;
    final h = size.height;
    final headWidth = w * 0.3;
    final headHeight = h * 0.8;
    final shaftHeight = h * 0.3;

    path.moveTo(0, h / 2 - shaftHeight / 2);
    path.lineTo(w - headWidth, h / 2 - shaftHeight / 2);
    path.lineTo(w - headWidth, h / 2 - headHeight / 2);
    path.lineTo(w, h / 2);
    path.lineTo(w - headWidth, h / 2 + headHeight / 2);
    path.lineTo(w - headWidth, h / 2 + shaftHeight / 2);
    path.lineTo(0, h / 2 + shaftHeight / 2);
    path.close();

    canvas.drawPath(path, paint);

    if (strokeWidth > 0) {
      final strokePaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
