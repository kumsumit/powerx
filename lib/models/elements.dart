import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'text_styles.dart';

abstract class SlideElement extends Equatable {
  final String id;
  final Offset position;
  final Size size;
  final double rotation;
  final bool isLocked;
  final int zIndex;
  final String? name;
  final bool hidden;

  const SlideElement({
    required this.id,
    required this.position,
    required this.size,
    this.rotation = 0.0,
    this.isLocked = false,
    required this.zIndex,
    this.name,
    this.hidden = false,
  });

  SlideElement copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    bool? isLocked,
    int? zIndex,
    String? name,
    bool? hidden,
  });
}

class TextElement extends SlideElement {
  final List<RichParagraph> paragraphs;
  final bool wrapText;
  final bool autoFit;
  final EdgeInsets padding;
  final Color? fillColor;
  final double? borderWidth;
  final Color? borderColor;

  const TextElement({
    required super.id,
    required super.position,
    required super.size,
    super.rotation,
    super.isLocked,
    required super.zIndex,
    super.name,
    super.hidden,
    this.paragraphs = const [RichParagraph()],
    this.wrapText = true,
    this.autoFit = false,
    this.padding = const EdgeInsets.all(4),
    this.fillColor,
    this.borderWidth,
    this.borderColor,
  });

  @override
  TextElement copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    bool? isLocked,
    int? zIndex,
    String? name,
    bool? hidden,
    List<RichParagraph>? paragraphs,
    bool? wrapText,
    bool? autoFit,
    EdgeInsets? padding,
    Color? fillColor,
    double? borderWidth,
    Color? borderColor,
  }) => TextElement(
    id: id,
    position: position ?? this.position,
    size: size ?? this.size,
    rotation: rotation ?? this.rotation,
    isLocked: isLocked ?? this.isLocked,
    zIndex: zIndex ?? this.zIndex,
    name: name ?? this.name,
    hidden: hidden ?? this.hidden,
    paragraphs: paragraphs ?? this.paragraphs,
    wrapText: wrapText ?? this.wrapText,
    autoFit: autoFit ?? this.autoFit,
    padding: padding ?? this.padding,
    fillColor: fillColor ?? this.fillColor,
    borderWidth: borderWidth ?? this.borderWidth,
    borderColor: borderColor ?? this.borderColor,
  );

  @override
  List<Object?> get props => [
    id,
    position,
    size,
    rotation,
    paragraphs,
    zIndex,
    hidden,
  ];
}

class ShapeElement extends SlideElement {
  final Color fillColor;
  final Color? gradientStart;
  final Color? gradientEnd;
  final GradientType? gradientType;
  final Color strokeColor;
  final double strokeWidth;
  final StrokeStyle strokeStyle;
  final ShapeType shapeType;
  final double? cornerRadius;
  final ShadowProperties? shadow;
  final bool flipHorizontal;
  final bool flipVertical;

  const ShapeElement({
    required super.id,
    required super.position,
    required super.size,
    super.rotation,
    super.isLocked,
    required super.zIndex,
    super.name,
    super.hidden,
    this.fillColor = const Color(0xFF4472C4),
    this.gradientStart,
    this.gradientEnd,
    this.gradientType,
    this.strokeColor = const Color(0xFF000000),
    this.strokeWidth = 0,
    this.strokeStyle = StrokeStyle.solid,
    this.shapeType = ShapeType.rectangle,
    this.cornerRadius,
    this.shadow,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });

  @override
  ShapeElement copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    bool? isLocked,
    int? zIndex,
    String? name,
    bool? hidden,
    Color? fillColor,
    Color? gradientStart,
    Color? gradientEnd,
    GradientType? gradientType,
    Color? strokeColor,
    double? strokeWidth,
    StrokeStyle? strokeStyle,
    ShapeType? shapeType,
    double? cornerRadius,
    ShadowProperties? shadow,
    bool? flipHorizontal,
    bool? flipVertical,
  }) => ShapeElement(
    id: id,
    position: position ?? this.position,
    size: size ?? this.size,
    rotation: rotation ?? this.rotation,
    isLocked: isLocked ?? this.isLocked,
    zIndex: zIndex ?? this.zIndex,
    name: name ?? this.name,
    hidden: hidden ?? this.hidden,
    fillColor: fillColor ?? this.fillColor,
    gradientStart: gradientStart ?? this.gradientStart,
    gradientEnd: gradientEnd ?? this.gradientEnd,
    gradientType: gradientType ?? this.gradientType,
    strokeColor: strokeColor ?? this.strokeColor,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    strokeStyle: strokeStyle ?? this.strokeStyle,
    shapeType: shapeType ?? this.shapeType,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    shadow: shadow ?? this.shadow,
    flipHorizontal: flipHorizontal ?? this.flipHorizontal,
    flipVertical: flipVertical ?? this.flipVertical,
  );

  @override
  List<Object?> get props => [
    id,
    position,
    size,
    fillColor,
    shapeType,
    zIndex,
    hidden,
  ];
}

class ImageElement extends SlideElement {
  final String imagePath;
  final ImageFillMode fillMode;
  final double? cropLeft;
  final double? cropTop;
  final double? cropRight;
  final double? cropBottom;
  final double brightness;
  final double contrast;
  final bool recolor;
  final Color? recolorColor;

  const ImageElement({
    required super.id,
    required super.position,
    required super.size,
    super.rotation,
    super.isLocked,
    required super.zIndex,
    super.name,
    super.hidden,
    required this.imagePath,
    this.fillMode = ImageFillMode.stretch,
    this.cropLeft,
    this.cropTop,
    this.cropRight,
    this.cropBottom,
    this.brightness = 0,
    this.contrast = 0,
    this.recolor = false,
    this.recolorColor,
  });

  @override
  ImageElement copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    bool? isLocked,
    int? zIndex,
    String? name,
    bool? hidden,
    String? imagePath,
    ImageFillMode? fillMode,
    double? brightness,
    double? contrast,
  }) => ImageElement(
    id: id,
    position: position ?? this.position,
    size: size ?? this.size,
    rotation: rotation ?? this.rotation,
    isLocked: isLocked ?? this.isLocked,
    zIndex: zIndex ?? this.zIndex,
    name: name ?? this.name,
    hidden: hidden ?? this.hidden,
    imagePath: imagePath ?? this.imagePath,
    fillMode: fillMode ?? this.fillMode,
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
  );

  @override
  List<Object?> get props => [id, position, size, imagePath, zIndex, hidden];
}

class VideoElement extends SlideElement {
  final String videoPath;
  final bool autoPlay;
  final bool loop;
  final double volume;

  const VideoElement({
    required super.id,
    required super.position,
    required super.size,
    super.rotation,
    super.isLocked,
    required super.zIndex,
    super.name,
    super.hidden,
    required this.videoPath,
    this.autoPlay = false,
    this.loop = false,
    this.volume = 1.0,
  });

  @override
  VideoElement copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    bool? isLocked,
    int? zIndex,
    String? name,
    bool? hidden,
    String? videoPath,
    bool? autoPlay,
    bool? loop,
    double? volume,
  }) => VideoElement(
    id: id,
    position: position ?? this.position,
    size: size ?? this.size,
    rotation: rotation ?? this.rotation,
    isLocked: isLocked ?? this.isLocked,
    zIndex: zIndex ?? this.zIndex,
    name: name ?? this.name,
    hidden: hidden ?? this.hidden,
    videoPath: videoPath ?? this.videoPath,
    autoPlay: autoPlay ?? this.autoPlay,
    loop: loop ?? this.loop,
    volume: volume ?? this.volume,
  );

  @override
  List<Object?> get props => [id, videoPath, zIndex];
}

class GroupElement extends SlideElement {
  final List<SlideElement> children;

  const GroupElement({
    required super.id,
    required super.position,
    required super.size,
    super.rotation,
    super.isLocked,
    required super.zIndex,
    super.name,
    super.hidden,
    required this.children,
  });

  @override
  GroupElement copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    bool? isLocked,
    int? zIndex,
    String? name,
    bool? hidden,
    List<SlideElement>? children,
  }) => GroupElement(
    id: id,
    position: position ?? this.position,
    size: size ?? this.size,
    rotation: rotation ?? this.rotation,
    isLocked: isLocked ?? this.isLocked,
    zIndex: zIndex ?? this.zIndex,
    name: name ?? this.name,
    hidden: hidden ?? this.hidden,
    children: children ?? this.children,
  );

  @override
  List<Object?> get props => [id, children, zIndex];
}

enum ShapeType {
  rectangle,
  roundedRectangle,
  circle,
  triangle,
  diamond,
  pentagon,
  hexagon,
  arrow,
  star,
  custom,
}

enum GradientType { linear, radial, rectangular, path }

enum StrokeStyle { solid, dash, dot, dashDot, dashDotDot }

enum ImageFillMode { stretch, fit, fill, tile, center }

class ShadowProperties extends Equatable {
  final Color color;
  final Offset offset;
  final double blurRadius;
  const ShadowProperties({
    this.color = const Color(0x80000000),
    this.offset = const Offset(2, 2),
    this.blurRadius = 4,
  });
  @override
  List<Object?> get props => [color, offset, blurRadius];
}
