import 'dart:ui';
import 'package:equatable/equatable.dart';
import 'elements.dart';

class ChartElement extends SlideElement {
  final ChartData data;
  final ChartType type;
  final ChartStyle style;
  final bool hasLegend;
  final LegendPosition legendPosition;
  final bool hasTitle;
  final String? title;

  const ChartElement({
    required super.id,
    required super.position,
    required super.size,
    super.rotation,
    super.isLocked,
    required super.zIndex,
    super.name,
    super.hidden,
    required this.data,
    this.type = ChartType.column,
    this.style = const ChartStyle(),
    this.hasLegend = true,
    this.legendPosition = LegendPosition.right,
    this.hasTitle = false,
    this.title,
  });

  @override
  ChartElement copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    bool? isLocked,
    int? zIndex,
    String? name,
    bool? hidden,
    ChartData? data,
    ChartType? type,
    ChartStyle? style,
    bool? hasLegend,
    LegendPosition? legendPosition,
    bool? hasTitle,
    String? title,
  }) => ChartElement(
    id: id,
    position: position ?? this.position,
    size: size ?? this.size,
    rotation: rotation ?? this.rotation,
    isLocked: isLocked ?? this.isLocked,
    zIndex: zIndex ?? this.zIndex,
    name: name ?? this.name,
    hidden: hidden ?? this.hidden,
    data: data ?? this.data,
    type: type ?? this.type,
    style: style ?? this.style,
    hasLegend: hasLegend ?? this.hasLegend,
    legendPosition: legendPosition ?? this.legendPosition,
    hasTitle: hasTitle ?? this.hasTitle,
    title: title ?? this.title,
  );

  @override
  List<Object?> get props => [id, data, type, zIndex];
}

class ChartData extends Equatable {
  final List<String> categories;
  final List<ChartSeries> series;
  const ChartData({this.categories = const [], this.series = const []});
  @override
  List<Object?> get props => [categories, series];
}

class ChartSeries extends Equatable {
  final String name;
  final List<double> values;
  final Color color;
  const ChartSeries({required this.name, required this.values, required this.color});
  @override
  List<Object?> get props => [name, values, color];
}

class ChartStyle extends Equatable {
  final Color backgroundColor;
  final Color plotAreaColor;
  const ChartStyle({this.backgroundColor = const Color(0xFFFFFFFF), this.plotAreaColor = const Color(0x00FFFFFF)});
  @override
  List<Object?> get props => [backgroundColor, plotAreaColor];
}

enum ChartType { column, bar, line, pie, area, scatter, radar }
enum LegendPosition { top, bottom, left, right }
