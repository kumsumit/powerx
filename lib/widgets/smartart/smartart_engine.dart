
import 'dart:math';
import 'package:flutter/material.dart';

enum SmartArtType {
  list,
  process,
  cycle,
  hierarchy,
  relationship,
  matrix,
  pyramid,
  pictureOrganization,
  equation,
  radial,
  target,
  venn,
  gear,
}

class SmartArtNode {
  final String id;
  final String text;
  final List<SmartArtNode> children;
  final int level;
  final Color? color;
  final String? imageUrl;
  
  SmartArtNode({
    required this.id,
    this.text = '',
    this.children = const [],
    this.level = 0,
    this.color,
    this.imageUrl,
  });
}

class SmartArtLayoutEngine {
  static List<NodePosition> calculateLayout(
    SmartArtType type,
    SmartArtNode root,
    Size bounds,
  ) {
    switch (type) {
      case SmartArtType.hierarchy:
        return _calculateHierarchy(root, bounds);
      case SmartArtType.radial:
        return _calculateRadial(root, bounds);
      case SmartArtType.cycle:
        return _calculateCycle(root, bounds);
      case SmartArtType.pyramid:
        return _calculatePyramid(root, bounds);
      case SmartArtType.venn:
        return _calculateVenn(root, bounds);
      case SmartArtType.matrix:
        return _calculateMatrix(root, bounds);
      case SmartArtType.process:
        return _calculateProcess(root, bounds);
      default:
        return _calculateList(root, bounds);
    }
  }

  static List<NodePosition> _calculateHierarchy(SmartArtNode root, Size bounds) {
    final positions = <NodePosition>[];
    final levelNodes = <int, List<SmartArtNode>>{};
    
    void collectLevels(SmartArtNode node, int level) {
      levelNodes.putIfAbsent(level, () => []).add(node);
      for (final child in node.children) {
        collectLevels(child, level + 1);
      }
    }
    collectLevels(root, 0);
    
    final maxLevel = levelNodes.keys.reduce((a, b) => a > b ? a : b);
    final levelHeight = bounds.height / (maxLevel + 1);
    
    for (int level = 0; level <= maxLevel; level++) {
      final nodes = levelNodes[level]!;
      final nodeWidth = bounds.width / (nodes.length + 1);
      for (int i = 0; i < nodes.length; i++) {
        positions.add(NodePosition(
          node: nodes[i],
          rect: Rect.fromCenter(
            center: Offset(
              nodeWidth * (i + 1),
              levelHeight * level + levelHeight / 2,
            ),
            width: nodeWidth * 0.8,
            height: levelHeight * 0.7,
          ),
        ));
      }
    }
    return positions;
  }

  static List<NodePosition> _calculateRadial(SmartArtNode root, Size bounds) {
    final positions = <NodePosition>[];
    final center = Offset(bounds.width / 2, bounds.height / 2);
    final radius = min(bounds.width, bounds.height) * 0.35;
    
    // Root at center
    positions.add(NodePosition(
      node: root,
      rect: Rect.fromCenter(center: center, width: 100, height: 60),
    ));
    
    // Children in circle
    final children = root.children;
    if (children.isEmpty) return positions;
    
    final angleStep = 2 * pi / children.length;
    for (int i = 0; i < children.length; i++) {
      final angle = angleStep * i - pi / 2;
      final pos = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      positions.add(NodePosition(
        node: children[i],
        rect: Rect.fromCenter(center: pos, width: 100, height: 60),
      ));
    }
    return positions;
  }

  static List<NodePosition> _calculateCycle(SmartArtNode root, Size bounds) {
    final positions = <NodePosition>[];
    final center = Offset(bounds.width / 2, bounds.height / 2);
    final radius = min(bounds.width, bounds.height) * 0.4;
    
    // Collect all nodes including root
    final allNodes = [root, ...root.children];
    final angleStep = 2 * pi / allNodes.length;
    
    for (int i = 0; i < allNodes.length; i++) {
      final angle = angleStep * i - pi / 2;
      final pos = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      positions.add(NodePosition(
        node: allNodes[i],
        rect: Rect.fromCenter(center: pos, width: 120, height: 80),
      ));
    }
    return positions;
  }

  static List<NodePosition> _calculatePyramid(SmartArtNode root, Size bounds) {
    final positions = <NodePosition>[];
    final allNodes = [root, ...root.children];
    final levels = allNodes.length;
    final levelHeight = bounds.height / levels;
    
    for (int i = 0; i < levels; i++) {
      final widthRatio = (levels - i) / levels;
      final width = bounds.width * widthRatio * 0.9;
      final y = levelHeight * i + levelHeight / 2;
      positions.add(NodePosition(
        node: allNodes[i],
        rect: Rect.fromCenter(
          center: Offset(bounds.width / 2, y),
          width: width,
          height: levelHeight * 0.8,
        ),
      ));
    }
    return positions;
  }

  static List<NodePosition> _calculateVenn(SmartArtNode root, Size bounds) {
    final positions = <NodePosition>[];
    final center = Offset(bounds.width / 2, bounds.height / 2);
    final radius = min(bounds.width, bounds.height) * 0.25;
    
    // 3-circle Venn diagram
    final offsets = [
      Offset(0, -radius * 0.5),
      Offset(-radius * 0.866, radius * 0.5),
      Offset(radius * 0.866, radius * 0.5),
    ];
    
    final nodes = [root, ...root.children.take(2)];
    for (int i = 0; i < nodes.length && i < 3; i++) {
      positions.add(NodePosition(
        node: nodes[i],
        rect: Rect.fromCenter(
          center: center + offsets[i],
          width: radius * 2,
          height: radius * 2,
        ),
      ));
    }
    return positions;
  }

  static List<NodePosition> _calculateMatrix(SmartArtNode root, Size bounds) {
    final positions = <NodePosition>[];
    final allNodes = [root, ...root.children];
    final cols = sqrt(allNodes.length).ceil();
    final rows = (allNodes.length / cols).ceil();
    final cellW = bounds.width / cols;
    final cellH = bounds.height / rows;
    
    for (int i = 0; i < allNodes.length; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      positions.add(NodePosition(
        node: allNodes[i],
        rect: Rect.fromCenter(
          center: Offset(
            cellW * col + cellW / 2,
            cellH * row + cellH / 2,
          ),
          width: cellW * 0.9,
          height: cellH * 0.9,
        ),
      ));
    }
    return positions;
  }

  static List<NodePosition> _calculateProcess(SmartArtNode root, Size bounds) {
    final positions = <NodePosition>[];
    final allNodes = [root, ...root.children];
    final stepW = bounds.width / allNodes.length;
    
    for (int i = 0; i < allNodes.length; i++) {
      positions.add(NodePosition(
        node: allNodes[i],
        rect: Rect.fromCenter(
          center: Offset(
            stepW * i + stepW / 2,
            bounds.height / 2,
          ),
          width: stepW * 0.85,
          height: bounds.height * 0.6,
        ),
      ));
    }
    return positions;
  }

  static List<NodePosition> _calculateList(SmartArtNode root, Size bounds) {
    final positions = <NodePosition>[];
    final allNodes = [root, ...root.children];
    final itemH = bounds.height / allNodes.length;
    
    for (int i = 0; i < allNodes.length; i++) {
      positions.add(NodePosition(
        node: allNodes[i],
        rect: Rect.fromLTWH(
          bounds.width * 0.05,
          itemH * i + itemH * 0.05,
          bounds.width * 0.9,
          itemH * 0.9,
        ),
      ));
    }
    return positions;
  }
}

class NodePosition {
  final SmartArtNode node;
  final Rect rect;
  NodePosition({required this.node, required this.rect});
}

class SmartArtRenderer extends StatelessWidget {
  final SmartArtType type;
  final SmartArtNode root;
  final Size size;

  const SmartArtRenderer({
    super.key,
    required this.type,
    required this.root,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final positions = SmartArtLayoutEngine.calculateLayout(type, root, size);
    
    return CustomPaint(
      size: size,
      painter: _SmartArtPainter(type: type, positions: positions),
      child: Stack(
        children: positions.map((pos) {
          return Positioned(
            left: pos.rect.left,
            top: pos.rect.top,
            width: pos.rect.width,
            height: pos.rect.height,
            child: Container(
              decoration: BoxDecoration(
                color: pos.node.color ?? Colors.blue[100],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue[800]!, width: 1),
              ),
              padding: const EdgeInsets.all(8),
              child: Center(
                child: Text(
                  pos.node.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SmartArtPainter extends CustomPainter {
  final SmartArtType type;
  final List<NodePosition> positions;

  _SmartArtPainter({required this.type, required this.positions});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw connections
    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      for (final child in pos.node.children) {
        final childPos = positions.firstWhere(
          (p) => p.node.id == child.id,
          orElse: () => positions[0],
        );
        
        final start = Offset(
          pos.rect.center.dx,
          pos.rect.bottom,
        );
        final end = Offset(
          childPos.rect.center.dx,
          childPos.rect.top,
        );
        
        if (type == SmartArtType.cycle) {
          // Draw curved connections for cycle
          final path = Path();
          path.moveTo(start.dx, start.dy);
          path.quadraticBezierTo(
            (start.dx + end.dx) / 2 + 20,
            (start.dy + end.dy) / 2,
            end.dx,
            end.dy,
          );
          canvas.drawPath(path, paint);
        } else {
          canvas.drawLine(start, end, paint);
        }
      }
    }

    // Draw arrows for process type
    if (type == SmartArtType.process) {
      for (int i = 0; i < positions.length - 1; i++) {
        final start = positions[i].rect.centerRight;
        final end = positions[i + 1].rect.centerLeft;
        _drawArrow(canvas, start, end, paint);
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    
    final angle = atan2(end.dy - start.dy, end.dx - start.dx);
    final arrowSize = 10.0;
    
    final path = Path();
    path.moveTo(end.dx, end.dy);
    path.lineTo(
      end.dx - arrowSize * cos(angle - pi / 6),
      end.dy - arrowSize * sin(angle - pi / 6),
    );
    path.moveTo(end.dx, end.dy);
    path.lineTo(
      end.dx - arrowSize * cos(angle + pi / 6),
      end.dy - arrowSize * sin(angle + pi / 6),
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
