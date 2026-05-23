import 'dart:ui';
import 'package:equatable/equatable.dart';
import 'elements.dart';
import 'text_styles.dart';
import 'theme.dart';

class SlideMaster extends Equatable {
  final String id;
  final String name;
  final Color backgroundColor;
  final BackgroundFill? backgroundFill;
  final List<SlideElement> elements;
  final List<Placeholder> placeholders;
  final PresentationTheme theme;

  const SlideMaster({
    required this.id,
    required this.name,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.backgroundFill,
    this.elements = const [],
    this.placeholders = const [],
    required this.theme,
  });

  @override
  List<Object?> get props => [id, name, backgroundColor, elements, placeholders];
}

class SlideLayout extends Equatable {
  final String id;
  final String name;
  final String masterId;
  final List<Placeholder> placeholders;
  final List<SlideElement> fixedElements;

  const SlideLayout({
    required this.id,
    required this.name,
    required this.masterId,
    this.placeholders = const [],
    this.fixedElements = const [],
  });

  @override
  List<Object?> get props => [id, name, masterId, placeholders];
}

class Placeholder extends Equatable {
  final String id;
  final PlaceholderType type;
  final Offset position;
  final Size size;
  final int zIndex;
  final List<RichParagraph>? defaultText;

  const Placeholder({
    required this.id,
    required this.type,
    required this.position,
    required this.size,
    this.zIndex = 0,
    this.defaultText,
  });

  @override
  List<Object?> get props => [id, type, position, size];
}

enum PlaceholderType { title, body, centerTitle, subTitle, date, footer, slideNumber, chart, table, picture, media, object }

class BackgroundFill extends Equatable {
  final BackgroundFillType type;
  final Color? solidColor;
  final GradientFill? gradient;
  final String? imagePath;
  const BackgroundFill({required this.type, this.solidColor, this.gradient, this.imagePath});
  @override
  List<Object?> get props => [type, solidColor, gradient, imagePath];
}

enum BackgroundFillType { solid, gradient, picture, pattern }

class GradientFill extends Equatable {
  final List<ColorStop> stops;
  final double angle;
  const GradientFill({this.stops = const [], this.angle = 0});
  @override
  List<Object?> get props => [stops, angle];
}

class ColorStop extends Equatable {
  final Color color;
  final double position;
  const ColorStop({required this.color, required this.position});
  @override
  List<Object?> get props => [color, position];
}
