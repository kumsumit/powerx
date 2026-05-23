import 'package:flutter/material.dart';

extension ColorExtension on Color {
  String toHex() =>
      '#${toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  Color darken(double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color lighten(double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}

extension OffsetExtension on Offset {
  Offset clamp(Rect bounds) {
    return Offset(
      dx.clamp(bounds.left, bounds.right),
      dy.clamp(bounds.top, bounds.bottom),
    );
  }
}

extension SizeExtension on Size {
  Size clamp(
    double minWidth,
    double minHeight,
    double maxWidth,
    double maxHeight,
  ) {
    return Size(
      width.clamp(minWidth, maxWidth),
      height.clamp(minHeight, maxHeight),
    );
  }
}
