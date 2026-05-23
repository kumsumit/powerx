import 'package:flutter/widgets.dart';
import '../../models/text_styles.dart';

/// Renders [RichParagraph]s the way PowerPoint lays out a text body: each
/// paragraph on its own line, indented by its outline level, with a leading
/// bullet or auto-number marker and the paragraph's own alignment.
///
/// Shared by the editor canvas (display mode) and the presenter view so both
/// stay consistent.
class RichParagraphsView extends StatelessWidget {
  final List<RichParagraph> paragraphs;

  /// Indentation applied per outline level, in logical pixels.
  final double levelIndent;

  const RichParagraphsView(
    this.paragraphs, {
    super.key,
    this.levelIndent = 18,
  });

  @override
  Widget build(BuildContext context) {
    final markers = _bulletMarkers(paragraphs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < paragraphs.length; i++)
          _paragraph(paragraphs[i], markers[i]),
      ],
    );
  }

  Widget _paragraph(RichParagraph para, String? marker) {
    final indent = para.style.level * levelIndent + para.style.indent;
    final firstRun = para.runs.isNotEmpty ? para.runs.first : const TextRun();

    // Preserve blank lines so spacing between paragraphs survives.
    if (para.plainText.isEmpty && marker == null) {
      return SizedBox(height: firstRun.fontSize);
    }

    final textSpan = TextSpan(children: [for (final r in para.runs) _span(r)]);
    final text = RichText(text: textSpan, textAlign: para.style.alignment);

    if (marker == null) {
      return Padding(
        padding: EdgeInsets.only(left: indent),
        child: text,
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$marker ',
            style: TextStyle(
              fontSize: firstRun.fontSize,
              color: firstRun.color,
              fontFamily: firstRun.fontFamily,
            ),
          ),
          Expanded(child: text),
        ],
      ),
    );
  }

  TextSpan _span(TextRun run) {
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
  }

  /// Resolves each paragraph's bullet marker, computing auto-number sequences
  /// per outline level (numbering resets when a shallower level intervenes).
  static List<String?> _bulletMarkers(List<RichParagraph> paragraphs) {
    final markers = List<String?>.filled(paragraphs.length, null);
    final counters = <int, int>{};
    for (var i = 0; i < paragraphs.length; i++) {
      final style = paragraphs[i].style;
      final level = style.level;
      switch (style.bulletType) {
        case BulletType.bullet:
        case BulletType.picture:
          markers[i] = style.bulletChar ?? '•';
          break;
        case BulletType.number:
          final next = (counters[level] ?? (style.startNumber ?? 1) - 1) + 1;
          counters[level] = next;
          counters.removeWhere((lvl, _) => lvl > level);
          markers[i] = '$next.';
          break;
        case BulletType.none:
          counters.removeWhere((lvl, _) => lvl > level);
          break;
      }
    }
    return markers;
  }
}
