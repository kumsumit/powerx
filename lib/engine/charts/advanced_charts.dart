import 'dart:math';
import 'package:flutter/material.dart';

enum AdvancedChartType {
  columnClustered,
  columnStacked,
  columnStacked100,
  barClustered,
  barStacked,
  barStacked100,
  line,
  lineStacked,
  lineStacked100,
  pie,
  pieExploded,
  doughnut,
  area,
  areaStacked,
  areaStacked100,
  scatter,
  scatterSmooth,
  bubble,
  radar,
  radarFilled,
  stockOHLC,
  stockHLC,
  surface,
  combo,
}

class ChartDataTable {
  final List<String> rowHeaders;
  final List<String> columnHeaders;
  final List<List<double>> data;
  final List<Color> seriesColors;

  ChartDataTable({
    required this.rowHeaders,
    required this.columnHeaders,
    required this.data,
    this.seriesColors = const [],
  });

  double get maxValue => data.expand((r) => r).reduce((a, b) => a > b ? a : b);
  double get minValue => data.expand((r) => r).reduce((a, b) => a < b ? a : b);

  List<double> getColumn(int index) => data.map((r) => r[index]).toList();
  List<double> getRow(int index) => data[index];

  ChartDataTable copyWith({
    List<String>? rowHeaders,
    List<String>? columnHeaders,
    List<List<double>>? data,
    List<Color>? seriesColors,
  }) => ChartDataTable(
    rowHeaders: rowHeaders ?? this.rowHeaders,
    columnHeaders: columnHeaders ?? this.columnHeaders,
    data: data ?? this.data,
    seriesColors: seriesColors ?? this.seriesColors,
  );
}

class AdvancedChartRenderer extends StatelessWidget {
  final AdvancedChartType type;
  final ChartDataTable data;
  final Size size;
  final ChartStyle style;
  final bool showLegend;
  final LegendPosition legendPosition;
  final bool showDataLabels;
  final bool showGridLines;
  final String? title;
  final String? xAxisTitle;
  final String? yAxisTitle;

  const AdvancedChartRenderer({
    super.key,
    required this.type,
    required this.data,
    required this.size,
    this.style = const ChartStyle(),
    this.showLegend = true,
    this.legendPosition = LegendPosition.right,
    this.showDataLabels = false,
    this.showGridLines = true,
    this.title,
    this.xAxisTitle,
    this.yAxisTitle,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size,
      painter: _AdvancedChartPainter(
        type: type,
        data: data,
        style: style,
        showLegend: showLegend,
        legendPosition: legendPosition,
        showDataLabels: showDataLabels,
        showGridLines: showGridLines,
        title: title,
        xAxisTitle: xAxisTitle,
        yAxisTitle: yAxisTitle,
      ),
    );
  }
}

class _AdvancedChartPainter extends CustomPainter {
  final AdvancedChartType type;
  final ChartDataTable data;
  final ChartStyle style;
  final bool showLegend;
  final LegendPosition legendPosition;
  final bool showDataLabels;
  final bool showGridLines;
  final String? title;
  final String? xAxisTitle;
  final String? yAxisTitle;

  _AdvancedChartPainter({
    required this.type,
    required this.data,
    required this.style,
    required this.showLegend,
    required this.legendPosition,
    required this.showDataLabels,
    required this.showGridLines,
    required this.title,
    required this.xAxisTitle,
    required this.yAxisTitle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plotArea = _calculatePlotArea(size);

    // Draw background
    canvas.drawRect(Offset.zero & size, Paint()..color = style.backgroundColor);

    // Draw title
    if (title != null) {
      _drawTitle(canvas, size);
    }

    // Draw plot area background
    canvas.drawRect(plotArea, Paint()..color = style.plotAreaColor);

    // Draw grid lines
    if (showGridLines) {
      _drawGridLines(canvas, plotArea);
    }

    // Draw chart based on type
    switch (type) {
      case AdvancedChartType.columnClustered:
      case AdvancedChartType.columnStacked:
      case AdvancedChartType.columnStacked100:
        _drawColumnChart(canvas, plotArea);
        break;
      case AdvancedChartType.barClustered:
      case AdvancedChartType.barStacked:
        _drawBarChart(canvas, plotArea);
        break;
      case AdvancedChartType.line:
      case AdvancedChartType.lineStacked:
        _drawLineChart(canvas, plotArea);
        break;
      case AdvancedChartType.pie:
      case AdvancedChartType.pieExploded:
      case AdvancedChartType.doughnut:
        _drawPieChart(canvas, plotArea);
        break;
      case AdvancedChartType.area:
      case AdvancedChartType.areaStacked:
        _drawAreaChart(canvas, plotArea);
        break;
      case AdvancedChartType.scatter:
      case AdvancedChartType.scatterSmooth:
        _drawScatterChart(canvas, plotArea);
        break;
      case AdvancedChartType.radar:
      case AdvancedChartType.radarFilled:
        _drawRadarChart(canvas, plotArea);
        break;
      case AdvancedChartType.bubble:
        _drawBubbleChart(canvas, plotArea);
        break;
      default:
        _drawColumnChart(canvas, plotArea);
    }

    // Draw axes
    _drawAxes(canvas, plotArea);

    // Draw legend
    if (showLegend) {
      _drawLegend(canvas, size, plotArea);
    }

    // Draw axis titles
    if (xAxisTitle != null) {
      _drawXAxisTitle(canvas, plotArea);
    }
    if (yAxisTitle != null) {
      _drawYAxisTitle(canvas, plotArea);
    }
  }

  Rect _calculatePlotArea(Size size) {
    double left = 60;
    double top = title != null ? 50 : 20;
    double right =
        size.width -
        (showLegend && legendPosition == LegendPosition.right ? 120 : 20);
    double bottom = size.height - (xAxisTitle != null ? 60 : 40);

    if (showLegend && legendPosition == LegendPosition.top) top += 40;
    if (showLegend && legendPosition == LegendPosition.bottom) bottom -= 40;

    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _drawTitle(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(minWidth: 0, maxWidth: size.width);
    textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, 10));
  }

  void _drawGridLines(Canvas canvas, Rect plotArea) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    final yRange = data.maxValue - data.minValue;
    final steps = 5;

    for (int i = 0; i <= steps; i++) {
      final value = data.minValue + (yRange * i / steps);
      final y = _valueToY(value, plotArea);
      canvas.drawLine(
        Offset(plotArea.left, y),
        Offset(plotArea.right, y),
        paint,
      );
    }
  }

  double _valueToY(double value, Rect plotArea) {
    final minValue = data.minValue;
    final range = data.maxValue - minValue;
    if (range == 0) return plotArea.center.dy;
    return plotArea.bottom - ((value - minValue) / range) * plotArea.height;
  }

  void _drawColumnChart(Canvas canvas, Rect plotArea) {
    final isStacked =
        type == AdvancedChartType.columnStacked ||
        type == AdvancedChartType.columnStacked100;
    final is100 = type == AdvancedChartType.columnStacked100;

    final categoryCount = data.rowHeaders.length;
    final seriesCount = data.columnHeaders.length;
    final groupWidth = plotArea.width / categoryCount;
    final barWidth = isStacked
        ? groupWidth * 0.6
        : (groupWidth * 0.8) / seriesCount;

    for (int cat = 0; cat < categoryCount; cat++) {
      double stackOffset = 0;
      double total = is100 ? data.getRow(cat).reduce((a, b) => a + b) : 1;

      for (int ser = 0; ser < seriesCount; ser++) {
        final value = data.data[cat][ser];
        final normalizedValue = is100 ? (value / total) : value;
        final barHeight =
            (normalizedValue / (is100 ? 1 : data.maxValue)) * plotArea.height;

        final x = isStacked
            ? plotArea.left + cat * groupWidth + (groupWidth - barWidth) / 2
            : plotArea.left +
                  cat * groupWidth +
                  (groupWidth - seriesCount * barWidth) / 2 +
                  ser * barWidth;
        final y = plotArea.bottom - barHeight - stackOffset;

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(2),
        );

        final paint = Paint()
          ..color = data.seriesColors.length > ser
              ? data.seriesColors[ser]
              : _defaultColor(ser);

        canvas.drawRRect(rect, paint);

        // Data label
        if (showDataLabels) {
          _drawDataLabel(
            canvas,
            x + barWidth / 2,
            y - 5,
            value.toStringAsFixed(1),
          );
        }

        if (isStacked) stackOffset += barHeight;
      }
    }
  }

  void _drawBarChart(Canvas canvas, Rect plotArea) {
    final isStacked = type == AdvancedChartType.barStacked;
    final categoryCount = data.rowHeaders.length;
    final seriesCount = data.columnHeaders.length;
    final groupHeight = plotArea.height / categoryCount;
    final barHeight = isStacked
        ? groupHeight * 0.6
        : (groupHeight * 0.8) / seriesCount;

    for (int cat = 0; cat < categoryCount; cat++) {
      double stackOffset = 0;

      for (int ser = 0; ser < seriesCount; ser++) {
        final value = data.data[cat][ser];
        final barWidth = (value / data.maxValue) * plotArea.width;

        final y = isStacked
            ? plotArea.top + cat * groupHeight + (groupHeight - barHeight) / 2
            : plotArea.top +
                  cat * groupHeight +
                  (groupHeight - seriesCount * barHeight) / 2 +
                  ser * barHeight;
        final x = plotArea.left + stackOffset;

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(2),
        );

        final paint = Paint()
          ..color = data.seriesColors.length > ser
              ? data.seriesColors[ser]
              : _defaultColor(ser);

        canvas.drawRRect(rect, paint);

        if (isStacked) stackOffset += barWidth;
      }
    }
  }

  void _drawLineChart(Canvas canvas, Rect plotArea) {
    final isStacked = type == AdvancedChartType.lineStacked;
    final seriesCount = data.columnHeaders.length;
    final pointCount = data.rowHeaders.length;
    final xStep = plotArea.width / (pointCount - 1);
    final stackedTotals = List<double>.filled(pointCount, 0);

    for (int ser = 0; ser < seriesCount; ser++) {
      final path = Path();
      final points = <Offset>[];

      for (int i = 0; i < pointCount; i++) {
        final value = data.data[i][ser];
        final plottedValue = isStacked ? stackedTotals[i] + value : value;
        if (isStacked) stackedTotals[i] = plottedValue;
        final x = plotArea.left + i * xStep;
        final y = _valueToY(plottedValue, plotArea);
        points.add(Offset(x, y));

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      // Draw line
      final linePaint = Paint()
        ..color = data.seriesColors.length > ser
            ? data.seriesColors[ser]
            : _defaultColor(ser)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      if (type == AdvancedChartType.scatterSmooth) {
        _drawSmoothLine(canvas, points, linePaint);
      } else {
        canvas.drawPath(path, linePaint);
      }

      // Draw points
      final pointPaint = Paint()
        ..color = data.seriesColors.length > ser
            ? data.seriesColors[ser]
            : _defaultColor(ser);

      for (final point in points) {
        canvas.drawCircle(point, 4, pointPaint);
      }
    }
  }

  void _drawSmoothLine(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 3) {
      final path = Path();
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
      return;
    }

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

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

    canvas.drawPath(path, paint);
  }

  void _drawPieChart(Canvas canvas, Rect plotArea) {
    final isDoughnut = type == AdvancedChartType.doughnut;
    final isExploded = type == AdvancedChartType.pieExploded;
    final center = plotArea.center;
    final radius = min(plotArea.width, plotArea.height) / 2 * 0.8;

    final total = data.data[0].reduce((a, b) => a + b);
    double startAngle = -pi / 2;

    for (int i = 0; i < data.columnHeaders.length; i++) {
      final value = data.data[0][i];
      final sweepAngle = (value / total) * 2 * pi;

      final paint = Paint()
        ..color = data.seriesColors.length > i
            ? data.seriesColors[i]
            : _defaultColor(i)
        ..style = PaintingStyle.fill;

      Offset sliceCenter = center;
      if (isExploded && i == 0) {
        final midAngle = startAngle + sweepAngle / 2;
        sliceCenter = Offset(
          center.dx + cos(midAngle) * 15,
          center.dy + sin(midAngle) * 15,
        );
      }

      canvas.drawArc(
        Rect.fromCircle(center: sliceCenter, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Draw border
      final borderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawArc(
        Rect.fromCircle(center: sliceCenter, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      startAngle += sweepAngle;
    }

    // Doughnut hole
    if (isDoughnut) {
      canvas.drawCircle(
        center,
        radius * 0.5,
        Paint()..color = style.backgroundColor,
      );
    }
  }

  void _drawAreaChart(Canvas canvas, Rect plotArea) {
    final seriesCount = data.columnHeaders.length;
    final pointCount = data.rowHeaders.length;
    final xStep = plotArea.width / (pointCount - 1);

    for (int ser = seriesCount - 1; ser >= 0; ser--) {
      final path = Path();
      path.moveTo(plotArea.left, plotArea.bottom);

      for (int i = 0; i < pointCount; i++) {
        final value = data.data[i][ser];
        final x = plotArea.left + i * xStep;
        final y = plotArea.bottom - (value / data.maxValue) * plotArea.height;
        path.lineTo(x, y);
      }

      path.lineTo(plotArea.right, plotArea.bottom);
      path.close();

      final paint = Paint()
        ..color =
            (data.seriesColors.length > ser
                    ? data.seriesColors[ser]
                    : _defaultColor(ser))
                .withOpacity(0.3 + (ser * 0.1));

      canvas.drawPath(path, paint);
    }

    // Draw lines on top
    _drawLineChart(canvas, plotArea);
  }

  void _drawScatterChart(Canvas canvas, Rect plotArea) {
    final xMax = data.data.map((r) => r[0]).reduce((a, b) => a > b ? a : b);
    final yMax = data.maxValue;

    for (int i = 0; i < data.rowHeaders.length; i++) {
      final x = plotArea.left + (data.data[i][0] / xMax) * plotArea.width;
      final y = plotArea.bottom - (data.data[i][1] / yMax) * plotArea.height;

      final paint = Paint()
        ..color = data.seriesColors.isNotEmpty
            ? data.seriesColors[0]
            : _defaultColor(0);

      canvas.drawCircle(Offset(x, y), 6, paint);
    }
  }

  void _drawRadarChart(Canvas canvas, Rect plotArea) {
    final center = plotArea.center;
    final radius = min(plotArea.width, plotArea.height) / 2 * 0.8;
    final axes = data.columnHeaders.length;
    final angleStep = 2 * pi / axes;

    // Draw web
    final webPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int ring = 1; ring <= 4; ring++) {
      final path = Path();
      for (int i = 0; i <= axes; i++) {
        final angle = i * angleStep - pi / 2;
        final r = radius * ring / 4;
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        if (i == 0)
          path.moveTo(x, y);
        else
          path.lineTo(x, y);
      }
      canvas.drawPath(path, webPaint);
    }

    // Draw axes
    for (int i = 0; i < axes; i++) {
      final angle = i * angleStep - pi / 2;
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * cos(angle),
          center.dy + radius * sin(angle),
        ),
        webPaint,
      );
    }

    // Draw data
    final isFilled = type == AdvancedChartType.radarFilled;
    for (int ser = 0; ser < data.rowHeaders.length; ser++) {
      final path = Path();
      final paint = Paint()
        ..color =
            (data.seriesColors.length > ser
                    ? data.seriesColors[ser]
                    : _defaultColor(ser))
                .withOpacity(isFilled ? 0.3 : 1.0)
        ..strokeWidth = 2
        ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke;

      for (int i = 0; i <= axes; i++) {
        final angle = i * angleStep - pi / 2;
        final value = data.data[ser][i % axes];
        final r = (value / data.maxValue) * radius;
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);

        if (i == 0)
          path.moveTo(x, y);
        else
          path.lineTo(x, y);
      }

      canvas.drawPath(path, paint);
    }
  }

  void _drawBubbleChart(Canvas canvas, Rect plotArea) {
    final xMax = data.data.map((r) => r[0]).reduce((a, b) => a > b ? a : b);
    final yMax = data.data.map((r) => r[1]).reduce((a, b) => a > b ? a : b);
    final sizeMax = data.data
        .map((r) => r.length > 2 ? r[2] : 1.0)
        .reduce((a, b) => a > b ? a : b);

    for (int i = 0; i < data.rowHeaders.length; i++) {
      final x = plotArea.left + (data.data[i][0] / xMax) * plotArea.width;
      final y = plotArea.bottom - (data.data[i][1] / yMax) * plotArea.height;
      final bubbleSize = data.data[i].length > 2 ? data.data[i][2] : 1.0;
      final radius = (bubbleSize / sizeMax) * 30;

      final paint = Paint()
        ..color =
            (data.seriesColors.isNotEmpty
                    ? data.seriesColors[0]
                    : _defaultColor(0))
                .withOpacity(0.6);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _drawAxes(Canvas canvas, Rect plotArea) {
    final axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;

    // Y axis
    canvas.drawLine(
      Offset(plotArea.left, plotArea.top),
      Offset(plotArea.left, plotArea.bottom),
      axisPaint,
    );

    // X axis
    canvas.drawLine(
      Offset(plotArea.left, plotArea.bottom),
      Offset(plotArea.right, plotArea.bottom),
      axisPaint,
    );

    // Y axis labels
    final steps = 5;
    for (int i = 0; i <= steps; i++) {
      final value = data.minValue + (data.maxValue - data.minValue) * i / steps;
      final y = plotArea.bottom - (plotArea.height * i / steps);

      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toStringAsFixed(0),
          style: const TextStyle(fontSize: 10, color: Colors.black),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          plotArea.left - textPainter.width - 5,
          y - textPainter.height / 2,
        ),
      );
    }

    // X axis labels
    final labelStep = max(1, data.rowHeaders.length ~/ 10);
    for (int i = 0; i < data.rowHeaders.length; i += labelStep) {
      final x =
          plotArea.left + (plotArea.width * i / (data.rowHeaders.length - 1));

      final textPainter = TextPainter(
        text: TextSpan(
          text: data.rowHeaders[i],
          style: const TextStyle(fontSize: 10, color: Colors.black),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, plotArea.bottom + 5),
      );
    }
  }

  void _drawLegend(Canvas canvas, Size size, Rect plotArea) {
    final legendItems = data.columnHeaders;
    final itemHeight = 20.0;

    double legendX, legendY;
    switch (legendPosition) {
      case LegendPosition.top:
        legendX = plotArea.left;
        legendY = 30;
        break;
      case LegendPosition.bottom:
        legendX = plotArea.left;
        legendY = size.height - 30;
        break;
      case LegendPosition.left:
        legendX = 10;
        legendY = plotArea.top;
        break;
      case LegendPosition.right:
        legendX = plotArea.right + 10;
        legendY = plotArea.top;
        break;
    }

    for (int i = 0; i < legendItems.length; i++) {
      final y = legendY + i * itemHeight;

      // Color box
      canvas.drawRect(
        Rect.fromLTWH(legendX, y, 12, 12),
        Paint()
          ..color = data.seriesColors.length > i
              ? data.seriesColors[i]
              : _defaultColor(i),
      );

      // Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: legendItems[i],
          style: const TextStyle(fontSize: 10, color: Colors.black),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(legendX + 18, y));
    }
  }

  void _drawDataLabel(Canvas canvas, double x, double y, String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 9, color: Colors.black),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height),
    );
  }

  void _drawXAxisTitle(Canvas canvas, Rect plotArea) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: xAxisTitle,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(plotArea.center.dx - textPainter.width / 2, plotArea.bottom + 35),
    );
  }

  void _drawYAxisTitle(Canvas canvas, Rect plotArea) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: yAxisTitle,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();

    canvas.save();
    canvas.translate(15, plotArea.center.dy);
    canvas.rotate(-pi / 2);
    textPainter.paint(canvas, Offset(-textPainter.width / 2, 0));
    canvas.restore();
  }

  Color _defaultColor(int index) {
    final colors = [
      const Color(0xFF4472C4),
      const Color(0xFFED7D31),
      const Color(0xFFA5A5A5),
      const Color(0xFFFFC000),
      const Color(0xFF5B9BD5),
      const Color(0xFF70AD47),
      const Color(0xFF264478),
      const Color(0xFF9E480E),
    ];
    return colors[index % colors.length];
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ChartStyle {
  final Color backgroundColor;
  final Color plotAreaColor;
  final Color gridLineColor;
  final Color axisColor;
  final Color textColor;

  const ChartStyle({
    this.backgroundColor = Colors.white,
    this.plotAreaColor = const Color(0x00FFFFFF),
    this.gridLineColor = const Color(0xFFE0E0E0),
    this.axisColor = Colors.black,
    this.textColor = Colors.black,
  });
}

enum LegendPosition { top, bottom, left, right }
