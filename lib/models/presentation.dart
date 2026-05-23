import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class Presentation extends Equatable {
  final String id;
  final String title;
  final List<Slide> slides;
  final SlideTheme theme;
  final int activeSlideIndex;

  const Presentation({
    required this.id,
    required this.title,
    required this.slides,
    this.theme = const SlideTheme(),
    this.activeSlideIndex = 0,
  });

  Presentation copyWith({
    String? title,
    List<Slide>? slides,
    SlideTheme? theme,
    int? activeSlideIndex,
  }) {
    return Presentation(
      id: id,
      title: title ?? this.title,
      slides: slides ?? this.slides,
      theme: theme ?? this.theme,
      activeSlideIndex: activeSlideIndex ?? this.activeSlideIndex,
    );
  }

  @override
  List<Object?> get props => [id, title, slides, theme, activeSlideIndex];
}

class Slide extends Equatable {
  final String id;
  final Color backgroundColor;
  final List<SlideElement> elements;
  final String? transition; // 'fade', 'push', etc.
  final String? notes;

  const Slide({
    required this.id,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.elements = const [],
    this.transition,
    this.notes,
  });

  Slide copyWith({
    Color? backgroundColor,
    List<SlideElement>? elements,
    String? transition,
    String? notes,
  }) {
    return Slide(
      id: id,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      elements: elements ?? this.elements,
      transition: transition ?? this.transition,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [id, backgroundColor, elements, transition, notes];
}

abstract class SlideElement extends Equatable {
  final String id;
  final Offset position;
  final Size size;
  final double rotation;
  final bool isLocked;
  final int zIndex;

  const SlideElement({
    required this.id,
    required this.position,
    required this.size,
    this.rotation = 0.0,
    this.isLocked = false,
    required this.zIndex,
  });

  SlideElement copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    bool? isLocked,
    int? zIndex,
  });
}

class TextElement extends SlideElement {
  final String text;
  final TextStyle style;
  final TextAlign align;

  const TextElement({
    required super.id,
    required super.position,
    required super.size,
    super.rotation,
    super.isLocked,
    required super.zIndex,
    this.text = 'Click to add text',
    this.style =  const TextStyle(fontSize: 18, color:  Colors.black),
    this.align = TextAlign.left,
  });

  @override
  TextElement copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    bool? isLocked,
    int? zIndex,
    String? text,
    TextStyle? style,
    TextAlign? align,
  }) {
    return TextElement(
      id: id,
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      isLocked: isLocked ?? this.isLocked,
      zIndex: zIndex ?? this.zIndex,
      text: text ?? this.text,
      style: style ?? this.style,
      align: align ?? this.align,
    );
  }

  @override
  List<Object?> get props => [id, position, size, rotation, text, style, align, zIndex];
}

class ShapeElement extends SlideElement {
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final ShapeType shapeType;

  const ShapeElement({
    required super.id,
    required super.position,
    required super.size,
    super.rotation,
    super.isLocked,
    required super.zIndex,
    this.fillColor = const Color(0xFF4472C4),
    this.strokeColor = const Color(0xFF000000),
    this.strokeWidth = 1.0,
    this.shapeType = ShapeType.rectangle,
  });

  @override
  ShapeElement copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    bool? isLocked,
    int? zIndex,
    Color? fillColor,
    Color? strokeColor,
    double? strokeWidth,
    ShapeType? shapeType,
  }) {
    return ShapeElement(
      id: id,
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      isLocked: isLocked ?? this.isLocked,
      zIndex: zIndex ?? this.zIndex,
      fillColor: fillColor ?? this.fillColor,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      shapeType: shapeType ?? this.shapeType,
    );
  }

  @override
  List<Object?> get props => [id, position, size, fillColor, shapeType, zIndex];
}

class ImageElement extends SlideElement {
  final String imagePath; // local path or base64

  const ImageElement({
    required super.id,
    required super.position,
    required super.size,
    super.rotation,
    super.isLocked,
    required super.zIndex,
    required this.imagePath,
  });

  @override
  ImageElement copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    bool? isLocked,
    int? zIndex,
    String? imagePath,
  }) {
    return ImageElement(
      id: id,
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      isLocked: isLocked ?? this.isLocked,
      zIndex: zIndex ?? this.zIndex,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  @override
  List<Object?> get props => [id, position, size, imagePath, zIndex];
}

enum ShapeType { rectangle, circle, triangle, arrow }

class SlideTheme extends Equatable {
  final Color primaryColor;
  final String fontFamily;

  const SlideTheme({
    this.primaryColor = const Color(0xFF4472C4),
    this.fontFamily = 'Calibri',
  });

  @override
  List<Object?> get props => [primaryColor, fontFamily];
}