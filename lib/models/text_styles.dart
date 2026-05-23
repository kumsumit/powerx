import 'dart:ui';
import 'package:equatable/equatable.dart';

enum BulletType { none, bullet, number, picture }

class ParagraphStyle extends Equatable {
  final TextAlign alignment;
  final double spaceBefore;
  final double spaceAfter;
  final double lineSpacing;
  final double indent;
  final double hangingIndent;
  final BulletType bulletType;
  final String? bulletChar;
  final int? startNumber;
  final int level;

  const ParagraphStyle({
    this.alignment = TextAlign.left,
    this.spaceBefore = 0,
    this.spaceAfter = 0,
    this.lineSpacing = 1.0,
    this.indent = 0,
    this.hangingIndent = 0,
    this.bulletType = BulletType.none,
    this.bulletChar,
    this.startNumber,
    this.level = 0,
  });

  ParagraphStyle copyWith({
    TextAlign? alignment,
    double? spaceBefore,
    double? spaceAfter,
    double? lineSpacing,
    double? indent,
    double? hangingIndent,
    BulletType? bulletType,
    String? bulletChar,
    int? startNumber,
    int? level,
  }) => ParagraphStyle(
    alignment: alignment ?? this.alignment,
    spaceBefore: spaceBefore ?? this.spaceBefore,
    spaceAfter: spaceAfter ?? this.spaceAfter,
    lineSpacing: lineSpacing ?? this.lineSpacing,
    indent: indent ?? this.indent,
    hangingIndent: hangingIndent ?? this.hangingIndent,
    bulletType: bulletType ?? this.bulletType,
    bulletChar: bulletChar ?? this.bulletChar,
    startNumber: startNumber ?? this.startNumber,
    level: level ?? this.level,
  );

  @override
  List<Object?> get props => [alignment, spaceBefore, spaceAfter, lineSpacing, indent, hangingIndent, bulletType, level];
}

class TextRun extends Equatable {
  final String text;
  final String fontFamily;
  final double fontSize;
  final Color color;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final double baselineOffset;
  final String? hyperlink;

  const TextRun({
    this.text = '',
    this.fontFamily = 'Calibri',
    this.fontSize = 18,
    this.color = const Color(0xFF000000),
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.baselineOffset = 0,
    this.hyperlink,
  });

  TextRun copyWith({
    String? text,
    String? fontFamily,
    double? fontSize,
    Color? color,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    double? baselineOffset,
    String? hyperlink,
  }) => TextRun(
    text: text ?? this.text,
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize: fontSize ?? this.fontSize,
    color: color ?? this.color,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    underline: underline ?? this.underline,
    strikethrough: strikethrough ?? this.strikethrough,
    baselineOffset: baselineOffset ?? this.baselineOffset,
    hyperlink: hyperlink ?? this.hyperlink,
  );

  @override
  List<Object?> get props => [text, fontFamily, fontSize, color, bold, italic, underline, strikethrough];
}

class RichParagraph extends Equatable {
  final List<TextRun> runs;
  final ParagraphStyle style;

  const RichParagraph({this.runs = const [], this.style = const ParagraphStyle()});

  RichParagraph copyWith({List<TextRun>? runs, ParagraphStyle? style}) =>
      RichParagraph(runs: runs ?? this.runs, style: style ?? this.style);

  String get plainText => runs.map((r) => r.text).join();

  @override
  List<Object?> get props => [runs, style];
}
