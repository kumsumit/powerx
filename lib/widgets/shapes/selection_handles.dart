import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/elements.dart';

class SelectionHandles extends StatelessWidget {
  final SlideElement element;
  final double zoom;
  final Offset overlayOffset;
  final Function(Size newSize, Offset newPosition) onResize;
  final Function(double newRotation)? onRotate;

  const SelectionHandles({
    super.key,
    required this.element,
    required this.zoom,
    this.overlayOffset = Offset.zero,
    required this.onResize,
    this.onRotate,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Edge resize strips (drawn first so corner handles sit on top).
        _buildEdge(HandlePosition.topCenter, element.size),
        _buildEdge(HandlePosition.bottomCenter, element.size),
        _buildEdge(HandlePosition.middleLeft, element.size),
        _buildEdge(HandlePosition.middleRight, element.size),
        // Corner handles
        _buildHandle(HandlePosition.topLeft, element.position, element.size),
        _buildHandle(HandlePosition.topCenter, element.position, element.size),
        _buildHandle(HandlePosition.topRight, element.position, element.size),
        _buildHandle(HandlePosition.middleLeft, element.position, element.size),
        _buildHandle(
          HandlePosition.middleRight,
          element.position,
          element.size,
        ),
        _buildHandle(HandlePosition.bottomLeft, element.position, element.size),
        _buildHandle(
          HandlePosition.bottomCenter,
          element.position,
          element.size,
        ),
        _buildHandle(
          HandlePosition.bottomRight,
          element.position,
          element.size,
        ),
        // Line connecting element to rotation handle
        Positioned(
          left: overlayOffset.dx + element.size.width / 2 - 0.5,
          top: overlayOffset.dy - 20,
          child: Container(
            width: 1,
            height: 20,
            color: const Color(0xFF4472C4),
          ),
        ),
        // Rotation handle
        Positioned(
          left: overlayOffset.dx + element.size.width / 2 - 14,
          top: overlayOffset.dy - 34,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (details) {
                if (onRotate == null) return;

                final renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox == null) return;

                final centerGlobal = renderBox.localToGlobal(
                  overlayOffset +
                      Offset(element.size.width / 2, element.size.height / 2),
                );
                final diff = details.globalPosition - centerGlobal;
                double angleRad = atan2(diff.dy, diff.dx);
                double rotation = (angleRad + pi / 2) * 180 / pi;
                rotation = (rotation % 360 + 360) % 360;
                onRotate!(rotation);
              },
              child: SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                      border: Border.fromBorderSide(
                        BorderSide(color: Color(0xFF4472C4), width: 1.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.rotate_right,
                      size: 11,
                      color: Color(0xFF4472C4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHandle(HandlePosition pos, Offset position, Size size) {
    final handleSize = 8.0 / zoom;
    final hitSize = 28.0 / zoom;
    late final double left, top;

    switch (pos) {
      case HandlePosition.topLeft:
        left = overlayOffset.dx - hitSize / 2;
        top = overlayOffset.dy - hitSize / 2;
        break;
      case HandlePosition.topCenter:
        left = overlayOffset.dx + size.width / 2 - hitSize / 2;
        top = overlayOffset.dy - hitSize / 2;
        break;
      case HandlePosition.topRight:
        left = overlayOffset.dx + size.width - hitSize / 2;
        top = overlayOffset.dy - hitSize / 2;
        break;
      case HandlePosition.middleLeft:
        left = overlayOffset.dx - hitSize / 2;
        top = overlayOffset.dy + size.height / 2 - hitSize / 2;
        break;
      case HandlePosition.middleRight:
        left = overlayOffset.dx + size.width - hitSize / 2;
        top = overlayOffset.dy + size.height / 2 - hitSize / 2;
        break;
      case HandlePosition.bottomLeft:
        left = overlayOffset.dx - hitSize / 2;
        top = overlayOffset.dy + size.height - hitSize / 2;
        break;
      case HandlePosition.bottomCenter:
        left = overlayOffset.dx + size.width / 2 - hitSize / 2;
        top = overlayOffset.dy + size.height - hitSize / 2;
        break;
      case HandlePosition.bottomRight:
        left = overlayOffset.dx + size.width - hitSize / 2;
        top = overlayOffset.dy + size.height - hitSize / 2;
        break;
    }

    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        cursor: _getCursor(pos),
        child: GestureDetector(
          // Opaque so a resize gesture is consumed here and never falls through
          // to the move detector underneath.
          behavior: HitTestBehavior.opaque,
          // delta is already in unscaled slide coords (inside Transform.scale).
          onPanUpdate: (details) => _handleResize(pos, details.delta),
          child: SizedBox(
            width: hitSize,
            height: hitSize,
            child: Center(
              child: Container(
                width: handleSize,
                height: handleSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFF4472C4),
                    width: 1.5 / zoom,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEdge(HandlePosition pos, Size size) {
    final edgeHitSize = 28.0 / zoom;
    late final double left, top, width, height;

    switch (pos) {
      case HandlePosition.topCenter:
        left = overlayOffset.dx + edgeHitSize / 2;
        top = overlayOffset.dy - edgeHitSize / 2;
        width = max(0, size.width - edgeHitSize);
        height = edgeHitSize;
        break;
      case HandlePosition.bottomCenter:
        left = overlayOffset.dx + edgeHitSize / 2;
        top = overlayOffset.dy + size.height - edgeHitSize / 2;
        width = max(0, size.width - edgeHitSize);
        height = edgeHitSize;
        break;
      case HandlePosition.middleLeft:
        left = overlayOffset.dx - edgeHitSize / 2;
        top = overlayOffset.dy + edgeHitSize / 2;
        width = edgeHitSize;
        height = max(0, size.height - edgeHitSize);
        break;
      case HandlePosition.middleRight:
        left = overlayOffset.dx + size.width - edgeHitSize / 2;
        top = overlayOffset.dy + edgeHitSize / 2;
        width = edgeHitSize;
        height = max(0, size.height - edgeHitSize);
        break;
      case HandlePosition.topLeft:
      case HandlePosition.topRight:
      case HandlePosition.bottomLeft:
      case HandlePosition.bottomRight:
        return const SizedBox.shrink();
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: _getCursor(pos),
        child: GestureDetector(
          // Opaque so a resize gesture is consumed here and never falls through
          // to the move detector underneath.
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => _handleResize(pos, details.delta),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  void _handleResize(HandlePosition pos, Offset delta) {
    const minSize = 10.0;

    final double rad = element.rotation * pi / 180;
    final double cosTheta = cos(rad);
    final double sinTheta = sin(rad);

    // Helper to rotate a local offset by the current rotation angle
    Offset rotate(Offset offset) {
      return Offset(
        offset.dx * cosTheta - offset.dy * sinTheta,
        offset.dx * sinTheta + offset.dy * cosTheta,
      );
    }

    final double w = element.size.width;
    final double h = element.size.height;
    final center = Offset(
      element.position.dx + w / 2,
      element.position.dy + h / 2,
    );

    // Determine the fixed point and size changes based on the handle position and local delta
    late final Offset localFixed;
    double newW = w;
    double newH = h;

    switch (pos) {
      case HandlePosition.topLeft:
        newW = max(minSize, w - delta.dx);
        newH = max(minSize, h - delta.dy);
        localFixed = Offset(w / 2, h / 2); // Bottom-right is fixed
        break;
      case HandlePosition.topCenter:
        newH = max(minSize, h - delta.dy);
        localFixed = Offset(0, h / 2); // Bottom-center is fixed
        break;
      case HandlePosition.topRight:
        newW = max(minSize, w + delta.dx);
        newH = max(minSize, h - delta.dy);
        localFixed = Offset(-w / 2, h / 2); // Bottom-left is fixed
        break;
      case HandlePosition.middleLeft:
        newW = max(minSize, w - delta.dx);
        localFixed = Offset(w / 2, 0); // Middle-right is fixed
        break;
      case HandlePosition.middleRight:
        newW = max(minSize, w + delta.dx);
        localFixed = Offset(-w / 2, 0); // Middle-left is fixed
        break;
      case HandlePosition.bottomLeft:
        newW = max(minSize, w - delta.dx);
        newH = max(minSize, h + delta.dy);
        localFixed = Offset(w / 2, -h / 2); // Top-right is fixed
        break;
      case HandlePosition.bottomCenter:
        newH = max(minSize, h + delta.dy);
        localFixed = Offset(0, -h / 2); // Top-center is fixed
        break;
      case HandlePosition.bottomRight:
        newW = max(minSize, w + delta.dx);
        newH = max(minSize, h + delta.dy);
        localFixed = Offset(-w / 2, -h / 2); // Top-left is fixed
        break;
    }

    // Fixed point in canvas space:
    final globalFixed = center + rotate(localFixed);

    // New local offset of the fixed point from the new center:
    late final Offset newLocalFixed;
    switch (pos) {
      case HandlePosition.topLeft:
        newLocalFixed = Offset(newW / 2, newH / 2);
        break;
      case HandlePosition.topCenter:
        newLocalFixed = Offset(0, newH / 2);
        break;
      case HandlePosition.topRight:
        newLocalFixed = Offset(-newW / 2, newH / 2);
        break;
      case HandlePosition.middleLeft:
        newLocalFixed = Offset(newW / 2, 0);
        break;
      case HandlePosition.middleRight:
        newLocalFixed = Offset(-newW / 2, 0);
        break;
      case HandlePosition.bottomLeft:
        newLocalFixed = Offset(newW / 2, -newH / 2);
        break;
      case HandlePosition.bottomCenter:
        newLocalFixed = Offset(0, -newH / 2);
        break;
      case HandlePosition.bottomRight:
        newLocalFixed = Offset(-newW / 2, -newH / 2);
        break;
    }

    // New center is globalFixed minus the rotated newLocalFixed offset:
    final newCenter = globalFixed - rotate(newLocalFixed);
    final newPos = Offset(newCenter.dx - newW / 2, newCenter.dy - newH / 2);

    onResize(Size(newW, newH), newPos);
  }

  MouseCursor _getCursor(HandlePosition pos) {
    switch (pos) {
      case HandlePosition.topLeft:
      case HandlePosition.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case HandlePosition.topRight:
      case HandlePosition.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
      case HandlePosition.topCenter:
      case HandlePosition.bottomCenter:
        return SystemMouseCursors.resizeUpDown;
      case HandlePosition.middleLeft:
      case HandlePosition.middleRight:
        return SystemMouseCursors.resizeLeftRight;
    }
  }
}

enum HandlePosition {
  topLeft,
  topCenter,
  topRight,
  middleLeft,
  middleRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}
