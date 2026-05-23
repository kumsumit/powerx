import 'dart:ui';
import 'package:equatable/equatable.dart';

class PresentationTheme extends Equatable {
  final String name;
  final ColorScheme colors;
  final FontScheme fonts;
  final EffectScheme effects;

  const PresentationTheme({
    this.name = 'Office',
    this.colors = const ColorScheme.office(),
    this.fonts = const FontScheme(),
    this.effects = const EffectScheme(),
  });

  PresentationTheme copyWith({
    String? name,
    ColorScheme? colors,
    FontScheme? fonts,
    EffectScheme? effects,
  }) => PresentationTheme(
    name: name ?? this.name,
    colors: colors ?? this.colors,
    fonts: fonts ?? this.fonts,
    effects: effects ?? this.effects,
  );

  @override
  List<Object?> get props => [name, colors, fonts, effects];
}

class ColorScheme extends Equatable {
  final Color text1;
  final Color background1;
  final Color accent1;
  final Color accent2;
  final Color accent3;
  final Color accent4;
  final Color accent5;
  final Color accent6;
  final Color hyperlink;
  final Color followedHyperlink;

  const ColorScheme({
    required this.text1,
    required this.background1,
    required this.accent1,
    required this.accent2,
    required this.accent3,
    required this.accent4,
    required this.accent5,
    required this.accent6,
    required this.hyperlink,
    required this.followedHyperlink,
  });

  const ColorScheme.office()
      : text1 = const Color(0xFF000000),
        background1 = const Color(0xFFFFFFFF),
        accent1 = const Color(0xFF4472C4),
        accent2 = const Color(0xFFED7D31),
        accent3 = const Color(0xFFA5A5A5),
        accent4 = const Color(0xFFFFC000),
        accent5 = const Color(0xFF5B9BD5),
        accent6 = const Color(0xFF70AD47),
        hyperlink = const Color(0xFF0563C1),
        followedHyperlink = const Color(0xFF954F72);

  @override
  List<Object?> get props => [text1, background1, accent1, accent2, accent3, accent4, accent5, accent6];
}

class FontScheme extends Equatable {
  final String majorFont;
  final String minorFont;
  const FontScheme({this.majorFont = 'Calibri', this.minorFont = 'Calibri'});
  @override
  List<Object?> get props => [majorFont, minorFont];
}

class EffectScheme extends Equatable {
  const EffectScheme();
  @override
  List<Object?> get props => [];
}
