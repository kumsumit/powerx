import 'dart:math';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart' as xml;

class EquationElement {
  final String type;
  final List<EquationElement> children;
  final String? text;
  final String? symbol;
  final EquationStyle? style;
  final FractionData? fraction;
  final ScriptData? script;
  final RadicalData? radical;
  final MatrixData? matrix;
  final AccentData? accent;
  final DelimiterData? delimiter;
  final UnderOverData? underOver;

  EquationElement({
    required this.type,
    this.children = const [],
    this.text,
    this.symbol,
    this.style,
    this.fraction,
    this.script,
    this.radical,
    this.matrix,
    this.accent,
    this.delimiter,
    this.underOver,
  });
}

class EquationStyle {
  final bool? bold;
  final bool? italic;
  final double? fontSize;
  final Color? color;
  final String? fontFamily;

  EquationStyle({
    this.bold,
    this.italic,
    this.fontSize,
    this.color,
    this.fontFamily,
  });
}

class FractionData {
  final EquationElement numerator;
  final EquationElement denominator;
  final bool? bevelled;
  final String? linethickness;

  FractionData({
    required this.numerator,
    required this.denominator,
    this.bevelled,
    this.linethickness,
  });
}

class ScriptData {
  final EquationElement base;
  final EquationElement? subscript;
  final EquationElement? superscript;

  ScriptData({required this.base, this.subscript, this.superscript});
}

class RadicalData {
  final EquationElement base;
  final EquationElement? index;

  RadicalData({required this.base, this.index});
}

class MatrixData {
  final List<List<EquationElement>> rows;

  MatrixData({required this.rows});
}

class AccentData {
  final EquationElement base;
  final String accent;

  AccentData({required this.base, required this.accent});
}

class DelimiterData {
  final String left;
  final String right;
  final EquationElement content;

  DelimiterData({
    required this.left,
    required this.right,
    required this.content,
  });
}

class UnderOverData {
  final EquationElement base;
  final EquationElement? underscript;
  final EquationElement? overscript;
  final String? accent;

  UnderOverData({
    required this.base,
    this.underscript,
    this.overscript,
    this.accent,
  });
}

class MathMLParser {
  static EquationElement parse(String mathml) {
    try {
      final document = xml.XmlDocument.parse(mathml);
      return _parseXmlElement(document.rootElement);
    } catch (_) {
      // Plain symbols and partial input are accepted while the user is typing.
    }
    return _parseElement(mathml);
  }

  static EquationElement _parseXmlElement(xml.XmlElement element) {
    switch (element.localName) {
      case 'math':
        return EquationElement(
          type: 'math',
          children: _parseXmlChildren(element),
        );
      case 'mrow':
        return EquationElement(
          type: 'row',
          children: _parseXmlChildren(element),
        );
      case 'mi':
        return EquationElement(type: 'identifier', text: element.innerText);
      case 'mn':
        return EquationElement(type: 'number', text: element.innerText);
      case 'mo':
        return EquationElement(type: 'operator', text: element.innerText);
      case 'mfrac':
        final children = _parseXmlChildren(element);
        return EquationElement(
          type: 'fraction',
          fraction: FractionData(
            numerator: children.isNotEmpty
                ? children[0]
                : EquationElement(type: 'text', text: ''),
            denominator: children.length > 1
                ? children[1]
                : EquationElement(type: 'text', text: ''),
          ),
        );
      case 'msub':
        final children = _parseXmlChildren(element);
        return EquationElement(
          type: 'subscript',
          script: ScriptData(
            base: children.isNotEmpty
                ? children[0]
                : EquationElement(type: 'text', text: ''),
            subscript: children.length > 1 ? children[1] : null,
          ),
        );
      case 'msup':
        final children = _parseXmlChildren(element);
        return EquationElement(
          type: 'superscript',
          script: ScriptData(
            base: children.isNotEmpty
                ? children[0]
                : EquationElement(type: 'text', text: ''),
            superscript: children.length > 1 ? children[1] : null,
          ),
        );
      case 'msubsup':
        final children = _parseXmlChildren(element);
        return EquationElement(
          type: 'subsuperscript',
          script: ScriptData(
            base: children.isNotEmpty
                ? children[0]
                : EquationElement(type: 'text', text: ''),
            subscript: children.length > 1 ? children[1] : null,
            superscript: children.length > 2 ? children[2] : null,
          ),
        );
      case 'msqrt':
        return EquationElement(
          type: 'sqrt',
          radical: RadicalData(
            base: EquationElement(
              type: 'row',
              children: _parseXmlChildren(element),
            ),
          ),
        );
      case 'mroot':
        final children = _parseXmlChildren(element);
        return EquationElement(
          type: 'root',
          radical: RadicalData(
            base: children.isNotEmpty
                ? children[0]
                : EquationElement(type: 'text', text: ''),
            index: children.length > 1 ? children[1] : null,
          ),
        );
      case 'mfenced':
        return EquationElement(
          type: 'fenced',
          delimiter: DelimiterData(
            left: element.getAttribute('open') ?? '(',
            right: element.getAttribute('close') ?? ')',
            content: EquationElement(
              type: 'row',
              children: _parseXmlChildren(element),
            ),
          ),
        );
      case 'munderover':
        final children = _parseXmlChildren(element);
        return EquationElement(
          type: 'underover',
          underOver: UnderOverData(
            base: children.isNotEmpty
                ? children[0]
                : EquationElement(type: 'text', text: ''),
            underscript: children.length > 1 ? children[1] : null,
            overscript: children.length > 2 ? children[2] : null,
          ),
        );
      case 'mtable':
        return _parseXmlMatrix(element);
      default:
        return EquationElement(type: 'text', text: element.innerText);
    }
  }

  static List<EquationElement> _parseXmlChildren(xml.XmlElement element) {
    final children = element.childElements.map(_parseXmlElement).toList();
    if (children.isNotEmpty) return children;
    final text = element.innerText.trim();
    return text.isEmpty
        ? const []
        : [EquationElement(type: 'text', text: text)];
  }

  static EquationElement _parseXmlMatrix(xml.XmlElement element) {
    final rows = element.findElements('mtr').map((row) {
      return row.findElements('mtd').map((cell) {
        return EquationElement(type: 'row', children: _parseXmlChildren(cell));
      }).toList();
    }).toList();
    return EquationElement(
      type: 'matrix',
      matrix: MatrixData(rows: rows),
    );
  }

  static EquationElement _parseElement(String xml) {
    // Strip whitespace and parse basic structure
    xml = xml.trim();

    if (xml.startsWith('<math')) {
      final content = _extractContent(xml, 'math');
      return EquationElement(type: 'math', children: [_parseElement(content)]);
    }

    if (xml.startsWith('<mrow')) {
      return _parseMRow(xml);
    }

    if (xml.startsWith('<mi')) {
      return EquationElement(type: 'identifier', text: _extractText(xml, 'mi'));
    }

    if (xml.startsWith('<mn')) {
      return EquationElement(type: 'number', text: _extractText(xml, 'mn'));
    }

    if (xml.startsWith('<mo')) {
      return EquationElement(type: 'operator', text: _extractText(xml, 'mo'));
    }

    if (xml.startsWith('<mfrac')) {
      return _parseFraction(xml);
    }

    if (xml.startsWith('<msub')) {
      return _parseSubscript(xml);
    }

    if (xml.startsWith('<msup')) {
      return _parseSuperscript(xml);
    }

    if (xml.startsWith('<msubsup')) {
      return _parseSubSuperscript(xml);
    }

    if (xml.startsWith('<msqrt')) {
      return _parseSqrt(xml);
    }

    if (xml.startsWith('<mroot')) {
      return _parseRoot(xml);
    }

    if (xml.startsWith('<mfenced')) {
      return _parseFenced(xml);
    }

    if (xml.startsWith('<munderover')) {
      return _parseUnderOver(xml);
    }

    if (xml.startsWith('<munder')) {
      return _parseUnder(xml);
    }

    if (xml.startsWith('<mover')) {
      return _parseOver(xml);
    }

    if (xml.startsWith('<mtable')) {
      return _parseMatrix(xml);
    }

    return EquationElement(type: 'text', text: xml);
  }

  static String _extractContent(String xml, String tag) {
    final start = xml.indexOf('>');
    final end = xml.lastIndexOf('</$tag>');
    if (start < 0 || end < 0) return '';
    return xml.substring(start + 1, end);
  }

  static String _extractText(String xml, String tag) {
    return _extractContent(xml, tag);
  }

  static EquationElement _parseMRow(String xml) {
    final content = _extractContent(xml, 'mrow');
    // Parse children
    return EquationElement(
      type: 'row',
      children: [EquationElement(type: 'text', text: content)],
    );
  }

  static EquationElement _parseFraction(String xml) {
    final content = _extractContent(xml, 'mfrac');
    final children = _parseElement('<mrow>$content</mrow>').children;
    // Extract numerator and denominator
    return EquationElement(
      type: 'fraction',
      fraction: FractionData(
        numerator: children.isNotEmpty
            ? children[0]
            : EquationElement(type: 'text', text: ''),
        denominator: children.length > 1
            ? children[1]
            : EquationElement(type: 'text', text: ''),
      ),
    );
  }

  static EquationElement _parseSubscript(String xml) {
    return EquationElement(
      type: 'subscript',
      script: ScriptData(
        base: EquationElement(type: 'text', text: 'x'),
        subscript: EquationElement(type: 'text', text: 'i'),
      ),
    );
  }

  static EquationElement _parseSuperscript(String xml) {
    return EquationElement(
      type: 'superscript',
      script: ScriptData(
        base: EquationElement(type: 'text', text: 'x'),
        superscript: EquationElement(type: 'text', text: '2'),
      ),
    );
  }

  static EquationElement _parseSubSuperscript(String xml) {
    return EquationElement(
      type: 'subsuperscript',
      script: ScriptData(
        base: EquationElement(type: 'text', text: 'x'),
        subscript: EquationElement(type: 'text', text: 'i'),
        superscript: EquationElement(type: 'text', text: '2'),
      ),
    );
  }

  static EquationElement _parseSqrt(String xml) {
    return EquationElement(
      type: 'sqrt',
      radical: RadicalData(
        base: EquationElement(type: 'text', text: 'x'),
      ),
    );
  }

  static EquationElement _parseRoot(String xml) {
    return EquationElement(
      type: 'root',
      radical: RadicalData(
        base: EquationElement(type: 'text', text: 'x'),
        index: EquationElement(type: 'text', text: '3'),
      ),
    );
  }

  static EquationElement _parseFenced(String xml) {
    return EquationElement(
      type: 'fenced',
      delimiter: DelimiterData(
        left: '(',
        right: ')',
        content: EquationElement(type: 'text', text: 'x'),
      ),
    );
  }

  static EquationElement _parseUnderOver(String xml) {
    return EquationElement(
      type: 'underover',
      underOver: UnderOverData(
        base: EquationElement(type: 'text', text: 'Σ'),
        underscript: EquationElement(type: 'text', text: 'i=0'),
        overscript: EquationElement(type: 'text', text: 'n'),
      ),
    );
  }

  static EquationElement _parseUnder(String xml) {
    return EquationElement(
      type: 'under',
      underOver: UnderOverData(
        base: EquationElement(type: 'text', text: 'lim'),
        underscript: EquationElement(type: 'text', text: 'x→∞'),
      ),
    );
  }

  static EquationElement _parseOver(String xml) {
    return EquationElement(
      type: 'over',
      underOver: UnderOverData(
        base: EquationElement(type: 'text', text: 'x'),
        overscript: EquationElement(type: 'text', text: '→'),
      ),
    );
  }

  static EquationElement _parseMatrix(String xml) {
    return EquationElement(
      type: 'matrix',
      matrix: MatrixData(
        rows: [
          [
            EquationElement(type: 'text', text: 'a'),
            EquationElement(type: 'text', text: 'b'),
          ],
          [
            EquationElement(type: 'text', text: 'c'),
            EquationElement(type: 'text', text: 'd'),
          ],
        ],
      ),
    );
  }
}

class EquationRenderer extends StatelessWidget {
  final EquationElement equation;
  final double fontSize;
  final Color color;

  const EquationRenderer({
    super.key,
    required this.equation,
    this.fontSize = 18,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final equationSize = _calculateSize(equation, fontSize);
    return CustomPaint(
      size: equationSize,
      painter: _EquationPainter(
        equation: equation,
        fontSize: fontSize,
        color: color,
      ),
    );
  }

  Size _calculateSize(EquationElement eq, double fontSize) {
    final width = _EquationPainter.measureElement(eq, fontSize);
    final height = _EquationPainter.measureHeight(eq, fontSize);
    return Size(width + 20, height + 20);
  }
}

class _EquationPainter extends CustomPainter {
  final EquationElement equation;
  final double fontSize;
  final Color color;

  _EquationPainter({
    required this.equation,
    required this.fontSize,
    required this.color,
  });

  static double measureElement(EquationElement element, double size) {
    switch (element.type) {
      case 'math':
      case 'row':
        if (element.children.isEmpty) return size;
        return element.children
            .map((child) => measureElement(child, size))
            .fold<double>(0, (sum, width) => sum + width + 4);
      case 'identifier':
      case 'number':
      case 'operator':
      case 'text':
        final textPainter = TextPainter(
          text: TextSpan(
            text: element.text ?? '',
            style: TextStyle(fontSize: size, fontFamily: 'Cambria Math'),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        return textPainter.width;
      case 'fraction':
        final data = element.fraction!;
        return max(
              measureElement(data.numerator, size * 0.85),
              measureElement(data.denominator, size * 0.85),
            ) +
            size;
      case 'subscript':
      case 'superscript':
        final data = element.script!;
        return measureElement(data.base, size) +
            measureElement(data.subscript ?? data.superscript!, size * 0.7);
      case 'subsuperscript':
        final data = element.script!;
        return measureElement(data.base, size) +
            max(
              data.subscript == null
                  ? 0
                  : measureElement(data.subscript!, size * 0.6),
              data.superscript == null
                  ? 0
                  : measureElement(data.superscript!, size * 0.6),
            );
      case 'sqrt':
      case 'root':
        return size * 0.8 + measureElement(element.radical!.base, size);
      case 'fenced':
        return size * 0.8 + measureElement(element.delimiter!.content, size);
      case 'underover':
        final data = element.underOver!;
        return [
          measureElement(data.base, size),
          if (data.underscript != null)
            measureElement(data.underscript!, size * 0.7),
          if (data.overscript != null)
            measureElement(data.overscript!, size * 0.7),
        ].reduce(max);
      case 'matrix':
        final rows = element.matrix!.rows;
        if (rows.isEmpty) return 0;
        final columns = rows.map((row) => row.length).fold<int>(0, max);
        return columns * size * 2 + 30;
      default:
        return size;
    }
  }

  static double measureHeight(EquationElement element, double size) {
    switch (element.type) {
      case 'math':
      case 'row':
        if (element.children.isEmpty) return size;
        return element.children
            .map((child) => measureHeight(child, size))
            .fold<double>(size, max);
      case 'fraction':
        return size * 2.3;
      case 'subscript':
      case 'superscript':
      case 'subsuperscript':
        return size * 1.7;
      case 'sqrt':
      case 'root':
        return max(size * 1.4, measureHeight(element.radical!.base, size));
      case 'underover':
        return size *
            (1 +
                (element.underOver!.underscript == null ? 0 : 0.7) +
                (element.underOver!.overscript == null ? 0 : 0.7));
      case 'matrix':
        final rows = element.matrix!.rows.length;
        return max(size, rows * size * 1.5);
      default:
        return size * 1.2;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawElement(canvas, equation, Offset(10, size.height / 2), fontSize);
  }

  double _drawElement(
    Canvas canvas,
    EquationElement element,
    Offset position,
    double size,
  ) {
    final textStyle = TextStyle(
      fontSize: size,
      color: color,
      fontFamily: 'Cambria Math',
      fontStyle: FontStyle.italic,
    );

    switch (element.type) {
      case 'math':
      case 'identifier':
      case 'number':
      case 'operator':
      case 'text':
        final text = element.text ?? '';
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: textStyle),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(position.dx, position.dy - textPainter.height / 2),
        );
        return textPainter.width;

      case 'fraction':
        return _drawFraction(canvas, element, position, size);

      case 'subscript':
        return _drawSubscript(canvas, element, position, size);

      case 'superscript':
        return _drawSuperscript(canvas, element, position, size);

      case 'subsuperscript':
        return _drawSubSuperscript(canvas, element, position, size);

      case 'sqrt':
        return _drawSqrt(canvas, element, position, size);

      case 'root':
        return _drawRoot(canvas, element, position, size);

      case 'fenced':
        return _drawFenced(canvas, element, position, size);

      case 'underover':
        return _drawUnderOver(canvas, element, position, size);

      case 'matrix':
        return _drawMatrix(canvas, element, position, size);

      case 'row':
        double x = position.dx;
        for (final child in element.children) {
          x += _drawElement(canvas, child, Offset(x, position.dy), size) + 4;
        }
        return x - position.dx;

      default:
        final textPainter = TextPainter(
          text: TextSpan(text: element.text ?? '', style: textStyle),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(position.dx, position.dy - textPainter.height / 2),
        );
        return textPainter.width;
    }
  }

  double _drawFraction(
    Canvas canvas,
    EquationElement element,
    Offset position,
    double size,
  ) {
    final data = element.fraction!;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final fractionWidth =
        max(
          _measureElement(data.numerator, size * 0.85),
          _measureElement(data.denominator, size * 0.85),
        ) +
        size;

    // Draw numerator
    final numWidth = _measureElement(data.numerator, size * 0.85);
    _drawElement(
      canvas,
      data.numerator,
      Offset(
        position.dx + (fractionWidth - numWidth) / 2,
        position.dy - size * 0.6,
      ),
      size * 0.85,
    );

    // Draw line
    canvas.drawLine(
      Offset(position.dx, position.dy),
      Offset(position.dx + fractionWidth, position.dy),
      linePaint,
    );

    // Draw denominator
    final denWidth = _measureElement(data.denominator, size * 0.85);
    _drawElement(
      canvas,
      data.denominator,
      Offset(
        position.dx + (fractionWidth - denWidth) / 2,
        position.dy + size * 0.3,
      ),
      size * 0.85,
    );

    return fractionWidth;
  }

  double _drawSubscript(
    Canvas canvas,
    EquationElement element,
    Offset position,
    double size,
  ) {
    final data = element.script!;
    final baseWidth = _drawElement(canvas, data.base, position, size);
    if (data.subscript != null) {
      _drawElement(
        canvas,
        data.subscript!,
        Offset(position.dx + baseWidth, position.dy + size * 0.3),
        size * 0.7,
      );
    }
    return baseWidth + size * 0.5;
  }

  double _drawSuperscript(
    Canvas canvas,
    EquationElement element,
    Offset position,
    double size,
  ) {
    final data = element.script!;
    final baseWidth = _drawElement(canvas, data.base, position, size);
    if (data.superscript != null) {
      _drawElement(
        canvas,
        data.superscript!,
        Offset(position.dx + baseWidth, position.dy - size * 0.4),
        size * 0.7,
      );
    }
    return baseWidth + size * 0.5;
  }

  double _drawSubSuperscript(
    Canvas canvas,
    EquationElement element,
    Offset position,
    double size,
  ) {
    final data = element.script!;
    final baseWidth = _drawElement(canvas, data.base, position, size);
    if (data.superscript != null) {
      _drawElement(
        canvas,
        data.superscript!,
        Offset(position.dx + baseWidth, position.dy - size * 0.4),
        size * 0.6,
      );
    }
    if (data.subscript != null) {
      _drawElement(
        canvas,
        data.subscript!,
        Offset(position.dx + baseWidth, position.dy + size * 0.3),
        size * 0.6,
      );
    }
    return baseWidth + size * 0.5;
  }

  double _drawSqrt(
    Canvas canvas,
    EquationElement element,
    Offset position,
    double size,
  ) {
    final data = element.radical!;
    final baseWidth = _measureElement(data.base, size);
    final totalWidth = baseWidth + size * 0.8;

    // Draw radical symbol
    final path = Path();
    path.moveTo(position.dx, position.dy + size * 0.3);
    path.lineTo(position.dx + size * 0.2, position.dy + size * 0.5);
    path.lineTo(position.dx + size * 0.4, position.dy - size * 0.5);
    path.lineTo(position.dx + size * 0.6, position.dy - size * 0.6);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, paint);

    // Draw top bar
    canvas.drawLine(
      Offset(position.dx + size * 0.5, position.dy - size * 0.6),
      Offset(position.dx + totalWidth, position.dy - size * 0.6),
      paint,
    );

    // Draw base
    _drawElement(
      canvas,
      data.base,
      Offset(position.dx + size * 0.7, position.dy),
      size,
    );

    return totalWidth;
  }

  double _drawRoot(
    Canvas canvas,
    EquationElement element,
    Offset position,
    double size,
  ) {
    final data = element.radical!;
    // Similar to sqrt but with index
    if (data.index != null) {
      _drawElement(
        canvas,
        data.index!,
        Offset(position.dx - size * 0.3, position.dy - size * 0.3),
        size * 0.6,
      );
    }
    return _drawSqrt(canvas, element, position, size);
  }

  double _drawFenced(
    Canvas canvas,
    EquationElement element,
    Offset position,
    double size,
  ) {
    final data = element.delimiter!;
    final contentWidth = _measureElement(data.content, size);
    final totalWidth = contentWidth + size * 0.8;

    // Draw left delimiter
    _drawDelimiter(
      canvas,
      data.left,
      position,
      size,
      contentWidth + size * 0.4,
    );

    // Draw content
    _drawElement(
      canvas,
      data.content,
      Offset(position.dx + size * 0.4, position.dy),
      size,
    );

    // Draw right delimiter
    _drawDelimiter(
      canvas,
      data.right,
      Offset(position.dx + size * 0.4 + contentWidth, position.dy),
      size,
      contentWidth + size * 0.4,
    );

    return totalWidth;
  }

  void _drawDelimiter(
    Canvas canvas,
    String delimiter,
    Offset position,
    double size,
    double height,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: delimiter,
        style: TextStyle(fontSize: size * 1.5, color: color),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.dx, position.dy - textPainter.height / 2),
    );
  }

  double _drawUnderOver(
    Canvas canvas,
    EquationElement element,
    Offset position,
    double size,
  ) {
    final data = element.underOver!;
    final baseWidth = _measureElement(data.base, size);

    // Draw overscript
    if (data.overscript != null) {
      final overWidth = _measureElement(data.overscript!, size * 0.7);
      _drawElement(
        canvas,
        data.overscript!,
        Offset(
          position.dx + (baseWidth - overWidth) / 2,
          position.dy - size * 0.8,
        ),
        size * 0.7,
      );
    }

    // Draw base
    _drawElement(canvas, data.base, position, size);

    // Draw underscript
    if (data.underscript != null) {
      final underWidth = _measureElement(data.underscript!, size * 0.7);
      _drawElement(
        canvas,
        data.underscript!,
        Offset(
          position.dx + (baseWidth - underWidth) / 2,
          position.dy + size * 0.6,
        ),
        size * 0.7,
      );
    }

    return baseWidth;
  }

  double _drawMatrix(
    Canvas canvas,
    EquationElement element,
    Offset position,
    double size,
  ) {
    final data = element.matrix!;
    final rows = data.rows;
    if (rows.isEmpty) return 0;

    final colCount = rows.first.length;
    final cellWidth = size * 2;
    final cellHeight = size * 1.5;

    for (int r = 0; r < rows.length; r++) {
      for (int c = 0; c < rows[r].length; c++) {
        final cellX = position.dx + c * cellWidth;
        final cellY =
            position.dy + r * cellHeight - (rows.length * cellHeight) / 2;
        _drawElement(canvas, rows[r][c], Offset(cellX, cellY), size * 0.9);
      }
    }

    // Draw brackets
    final bracketHeight = rows.length * cellHeight;
    final bracketPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Left bracket
    final leftPath = Path();
    leftPath.moveTo(position.dx - 5, position.dy - bracketHeight / 2);
    leftPath.lineTo(position.dx - 15, position.dy - bracketHeight / 2);
    leftPath.lineTo(position.dx - 15, position.dy + bracketHeight / 2);
    leftPath.lineTo(position.dx - 5, position.dy + bracketHeight / 2);
    canvas.drawPath(leftPath, bracketPaint);

    // Right bracket
    final rightPath = Path();
    rightPath.moveTo(
      position.dx + colCount * cellWidth + 5,
      position.dy - bracketHeight / 2,
    );
    rightPath.lineTo(
      position.dx + colCount * cellWidth + 15,
      position.dy - bracketHeight / 2,
    );
    rightPath.lineTo(
      position.dx + colCount * cellWidth + 15,
      position.dy + bracketHeight / 2,
    );
    rightPath.lineTo(
      position.dx + colCount * cellWidth + 5,
      position.dy + bracketHeight / 2,
    );
    canvas.drawPath(rightPath, bracketPaint);

    return colCount * cellWidth + 30;
  }

  double _measureElement(EquationElement element, double size) {
    return measureElement(element, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Equation editor widget
class EquationEditor extends StatefulWidget {
  final String initialEquation;
  final Function(String) onChanged;

  const EquationEditor({
    super.key,
    this.initialEquation = '',
    required this.onChanged,
  });

  @override
  State<EquationEditor> createState() => _EquationEditorState();
}

class _EquationEditorState extends State<EquationEditor> {
  late TextEditingController _controller;
  EquationElement? _parsedEquation;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEquation);
    _parseEquation();
  }

  void _parseEquation() {
    setState(() {
      _parsedEquation = MathMLParser.parse(_controller.text);
    });
    widget.onChanged(_controller.text);
  }

  void _insertSymbol(String symbol) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start.clamp(0, text.length).toInt();
    final end = selection.end.clamp(start, text.length).toInt();
    final newText = text.replaceRange(start, end, symbol);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: start + symbol.length,
    );
    _parseEquation();
  }

  void _insertTemplate(String template) {
    _insertSymbol(template);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Preview
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: _parsedEquation != null
                ? EquationRenderer(equation: _parsedEquation!)
                : const Text('Enter an equation'),
          ),
        ),
        const SizedBox(height: 8),
        // Toolbar
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _buildSymbolButton('x²', '<msup><mi>x</mi><mn>2</mn></msup>'),
            _buildSymbolButton('xᵢ', '<msub><mi>x</mi><mi>i</mi></msub>'),
            _buildSymbolButton('½', '<mfrac><mn>1</mn><mn>2</mn></mfrac>'),
            _buildSymbolButton('√', '<msqrt><mi>x</mi></msqrt>'),
            _buildSymbolButton(
              '∑',
              '<munderover><mo>∑</mo><mrow><mi>i</mi><mo>=</mo><mn>0</mn></mrow><mi>n</mi></munderover>',
            ),
            _buildSymbolButton(
              '∫',
              '<munderover><mo>∫</mo><mi>a</mi><mi>b</mi></munderover>',
            ),
            _buildSymbolButton('α', 'α'),
            _buildSymbolButton('β', 'β'),
            _buildSymbolButton('π', 'π'),
            _buildSymbolButton('∞', '∞'),
            _buildSymbolButton('≠', '≠'),
            _buildSymbolButton('≤', '≤'),
            _buildSymbolButton('≥', '≥'),
            _buildSymbolButton('±', '±'),
            _buildSymbolButton('÷', '÷'),
            _buildSymbolButton('×', '×'),
          ],
        ),
        const SizedBox(height: 8),
        // Editor
        TextField(
          controller: _controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Enter MathML or LaTeX...',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _parseEquation(),
        ),
      ],
    );
  }

  Widget _buildSymbolButton(String label, String mathml) {
    return ElevatedButton(
      onPressed: () => _insertTemplate(mathml),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
      ),
      child: Text(label, style: const TextStyle(fontSize: 16)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
