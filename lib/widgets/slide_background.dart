import 'dart:math';

import 'package:flutter/material.dart';

import '../models/slide_master.dart';

class SlideBackground extends StatelessWidget {
  final double? width;
  final double? height;
  final Color? color;
  final BackgroundFill? fill;
  final Widget child;

  const SlideBackground({
    super.key,
    this.width,
    this.height,
    this.color,
    this.fill,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: fill?.type == BackgroundFillType.gradient ? null : _solidColor(),
      decoration: _decoration(),
      child: child,
    );
  }

  Color _solidColor() {
    return fill?.solidColor ?? color ?? Colors.white;
  }

  BoxDecoration? _decoration() {
    final gradient = fill?.gradient;
    if (fill?.type != BackgroundFillType.gradient ||
        gradient == null ||
        gradient.stops.length < 2) {
      return null;
    }

    final radians = gradient.angle * pi / 180;
    final direction = Alignment(cos(radians), sin(radians));
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment(-direction.x, -direction.y),
        end: direction,
        colors: gradient.stops.map((stop) => stop.color).toList(),
        stops: gradient.stops.map((stop) => stop.position).toList(),
      ),
    );
  }
}
