import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/elements.dart';

class SelectionHandles extends StatelessWidget {
  final SlideElement element;
  final Function(Size newSize, Offset newPosition) onResize;

  const SelectionHandles({super.key, required this.element, required this.onResize});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Corner handles
        _buildHandle(HandlePosition.topLeft, element.position, element.size),
        _buildHandle(HandlePosition.topCenter, element.position, element.size),
        _buildHandle(HandlePosition.topRight, element.position, element.size),
        _buildHandle(HandlePosition.middleLeft, element.position, element.size),
        _buildHandle(HandlePosition.middleRight, element.position, element.size),
        _buildHandle(HandlePosition.bottomLeft, element.position, element.size),
        _buildHandle(HandlePosition.bottomCenter, element.position, element.size),
        _buildHandle(HandlePosition.bottomRight, element.position, element.size),
        // Rotation handle
        Positioned(
          left: element.size.width / 2 - 6,
          top: -20,
          child: GestureDetector(
            onPanUpdate: (details) {
              // Rotation logic would go here
            },
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(BorderSide(color: Color(0xFF4472C4), width: 1.5)),
              ),
              child: const Icon(Icons.rotate_right, size: 8, color: Color(0xFF4472C4)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHandle(HandlePosition pos, Offset position, Size size) {
    final handleSize = 8.0;
    late final double left, top;

    switch (pos) {
      case HandlePosition.topLeft:
        left = -handleSize / 2; top = -handleSize / 2;
        break;
      case HandlePosition.topCenter:
        left = size.width / 2 - handleSize / 2; top = -handleSize / 2;
        break;
      case HandlePosition.topRight:
        left = size.width - handleSize / 2; top = -handleSize / 2;
        break;
      case HandlePosition.middleLeft:
        left = -handleSize / 2; top = size.height / 2 - handleSize / 2;
        break;
      case HandlePosition.middleRight:
        left = size.width - handleSize / 2; top = size.height / 2 - handleSize / 2;
        break;
      case HandlePosition.bottomLeft:
        left = -handleSize / 2; top = size.height - handleSize / 2;
        break;
      case HandlePosition.bottomCenter:
        left = size.width / 2 - handleSize / 2; top = size.height - handleSize / 2;
        break;
      case HandlePosition.bottomRight:
        left = size.width - handleSize / 2; top = size.height - handleSize / 2;
        break;
    }

    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        cursor: _getCursor(pos),
        child: GestureDetector(
          onPanUpdate: (details) => _handleResize(pos, details.delta),
          child: Container(
            width: handleSize,
            height: handleSize,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFF4472C4), width: 1.5),
            ),
          ),
        ),
      ),
    );
  }

  void _handleResize(HandlePosition pos, Offset delta) {
    var newSize = element.size;
    var newPos = element.position;

    switch (pos) {
      case HandlePosition.topLeft:
        newSize = Size(max(10, element.size.width - delta.dx), max(10, element.size.height - delta.dy));
        newPos = Offset(element.position.dx + delta.dx, element.position.dy + delta.dy);
        break;
      case HandlePosition.topCenter:
        newSize = Size(element.size.width, max(10, element.size.height - delta.dy));
        newPos = Offset(element.position.dx, element.position.dy + delta.dy);
        break;
      case HandlePosition.topRight:
        newSize = Size(max(10, element.size.width + delta.dx), max(10, element.size.height - delta.dy));
        newPos = Offset(element.position.dx, element.position.dy + delta.dy);
        break;
      case HandlePosition.middleLeft:
        newSize = Size(max(10, element.size.width - delta.dx), element.size.height);
        newPos = Offset(element.position.dx + delta.dx, element.position.dy);
        break;
      case HandlePosition.middleRight:
        newSize = Size(max(10, element.size.width + delta.dx), element.size.height);
        break;
      case HandlePosition.bottomLeft:
        newSize = Size(max(10, element.size.width - delta.dx), max(10, element.size.height + delta.dy));
        newPos = Offset(element.position.dx + delta.dx, element.position.dy);
        break;
      case HandlePosition.bottomCenter:
        newSize = Size(element.size.width, max(10, element.size.height + delta.dy));
        break;
      case HandlePosition.bottomRight:
        newSize = Size(max(10, element.size.width + delta.dx), max(10, element.size.height + delta.dy));
        break;
    }

    onResize(newSize, newPos);
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

enum HandlePosition { topLeft, topCenter, topRight, middleLeft, middleRight, bottomLeft, bottomCenter, bottomRight }
