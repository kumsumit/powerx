import 'dart:math';
import 'package:flutter/material.dart';

class ThreeDTransform {
  final double rotationX;
  final double rotationY;
  final double rotationZ;
  final double depth;
  final Offset perspectiveOrigin;
  final double perspective;

  const ThreeDTransform({
    this.rotationX = 0,
    this.rotationY = 0,
    this.rotationZ = 0,
    this.depth = 0,
    this.perspectiveOrigin = const Offset(0.5, 0.5),
    this.perspective = 1000,
  });

  ThreeDTransform copyWith({
    double? rotationX,
    double? rotationY,
    double? rotationZ,
    double? depth,
    Offset? perspectiveOrigin,
    double? perspective,
  }) => ThreeDTransform(
    rotationX: rotationX ?? this.rotationX,
    rotationY: rotationY ?? this.rotationY,
    rotationZ: rotationZ ?? this.rotationZ,
    depth: depth ?? this.depth,
    perspectiveOrigin: perspectiveOrigin ?? this.perspectiveOrigin,
    perspective: perspective ?? this.perspective,
  );

  Matrix4 get matrix {
    final matrix = Matrix4.identity();
    
    // Apply perspective
    matrix.setEntry(3, 2, -1 / perspective);
    
    // Apply rotations (in degrees)
    matrix.rotateX(rotationX * pi / 180);
    matrix.rotateY(rotationY * pi / 180);
    matrix.rotateZ(rotationZ * pi / 180);
    
    // Apply depth translation
    matrix.translate(0.0, 0.0, depth);
    
    return matrix;
  }
}

class ThreeDShape {
  final List<ThreeDVertex> vertices;
  final List<ThreeDFace> faces;
  final Color color;
  final ThreeDTransform transform;

  ThreeDShape({
    required this.vertices,
    required this.faces,
    this.color = Colors.blue,
    this.transform = const ThreeDTransform(),
  });

  ThreeDShape.cube({
    double size = 100,
    this.color = Colors.blue,
    this.transform = const ThreeDTransform(),
  }) : vertices = [
    ThreeDVertex(-size/2, -size/2, -size/2), // 0: front-top-left
    ThreeDVertex(size/2, -size/2, -size/2),  // 1: front-top-right
    ThreeDVertex(size/2, size/2, -size/2),   // 2: front-bottom-right
    ThreeDVertex(-size/2, size/2, -size/2),  // 3: front-bottom-left
    ThreeDVertex(-size/2, -size/2, size/2),  // 4: back-top-left
    ThreeDVertex(size/2, -size/2, size/2),   // 5: back-top-right
    ThreeDVertex(size/2, size/2, size/2),    // 6: back-bottom-right
    ThreeDVertex(-size/2, size/2, size/2),   // 7: back-bottom-left
  ], faces = [
    ThreeDFace([0, 1, 2, 3], Colors.red.withOpacity(0.7)),      // Front
    ThreeDFace([5, 4, 7, 6], Colors.green.withOpacity(0.7)),  // Back
    ThreeDFace([4, 0, 3, 7], Colors.blue.withOpacity(0.7)),     // Left
    ThreeDFace([1, 5, 6, 2], Colors.yellow.withOpacity(0.7)),   // Right
    ThreeDFace([4, 5, 1, 0], Colors.purple.withOpacity(0.7)),  // Top
    ThreeDFace([3, 2, 6, 7], Colors.orange.withOpacity(0.7)),  // Bottom
  ];

  ThreeDShape.pyramid({
    double base = 100,
    double height = 150,
    this.color = Colors.blue,
    this.transform = const ThreeDTransform(),
  }) : vertices = [
    ThreeDVertex(-base/2, height/2, -base/2),  // 0: base-front-left
    ThreeDVertex(base/2, height/2, -base/2),   // 1: base-front-right
    ThreeDVertex(base/2, height/2, base/2),    // 2: base-back-right
    ThreeDVertex(-base/2, height/2, base/2),   // 3: base-back-left
    ThreeDVertex(0, -height/2, 0),             // 4: apex
  ], faces = [
    ThreeDFace([0, 1, 2, 3], Colors.red.withOpacity(0.7)),      // Base
    ThreeDFace([0, 1, 4], Colors.green.withOpacity(0.7)),       // Front
    ThreeDFace([1, 2, 4], Colors.blue.withOpacity(0.7)),          // Right
    ThreeDFace([2, 3, 4], Colors.yellow.withOpacity(0.7)),      // Back
    ThreeDFace([3, 0, 4], Colors.purple.withOpacity(0.7)),       // Left
  ];

  ThreeDShape.cylinder({
    double radius = 50,
    double height = 100,
    int segments = 16,
    this.color = Colors.blue,
    this.transform = const ThreeDTransform(),
  }) : vertices = [], faces = [] {
    // Generate cylinder vertices
    for (int i = 0; i < segments; i++) {
      final angle = 2 * pi * i / segments;
      final x = radius * cos(angle);
      final z = radius * sin(angle);
      vertices.add(ThreeDVertex(x, -height/2, z)); // Bottom circle
      vertices.add(ThreeDVertex(x, height/2, z));  // Top circle
    }
    
    // Generate faces
    for (int i = 0; i < segments; i++) {
      final next = (i + 1) % segments;
      faces.add(ThreeDFace(
        [i * 2, next * 2, next * 2 + 1, i * 2 + 1],
        color.withOpacity(0.7),
      ));
    }
  }

  ThreeDShape.sphere({
    double radius = 50,
    int latSegments = 16,
    int lonSegments = 16,
    this.color = Colors.blue,
    this.transform = const ThreeDTransform(),
  }) : vertices = [], faces = [] {
    // Generate sphere vertices using spherical coordinates
    for (int lat = 0; lat <= latSegments; lat++) {
      final theta = pi * lat / latSegments;
      for (int lon = 0; lon <= lonSegments; lon++) {
        final phi = 2 * pi * lon / lonSegments;
        final x = radius * sin(theta) * cos(phi);
        final y = radius * cos(theta);
        final z = radius * sin(theta) * sin(phi);
        vertices.add(ThreeDVertex(x, y, z));
      }
    }
    
    // Generate faces
    for (int lat = 0; lat < latSegments; lat++) {
      for (int lon = 0; lon < lonSegments; lon++) {
        final current = lat * (lonSegments + 1) + lon;
        final next = current + lonSegments + 1;
        faces.add(ThreeDFace(
          [current, current + 1, next + 1, next],
          color.withOpacity(0.7),
        ));
      }
    }
  }
}

class ThreeDVertex {
  final double x, y, z;
  ThreeDVertex(this.x, this.y, this.z);
  
  Offset project(Matrix4 transform, Size viewSize, double scale) {
    final vector = Vec3(x, y, z);
    final transformed = transform.transformVec3(vector);
    
    final px = (transformed.x * scale) + viewSize.width / 2;
    final py = (transformed.y * scale) + viewSize.height / 2;
    
    return Offset(px, py);
  }
}

class ThreeDFace {
  final List<int> vertexIndices;
  final Color color;
  
  ThreeDFace(this.vertexIndices, this.color);
  
  bool isVisible(List<ThreeDVertex> vertices, Matrix4 transform) {
    if (vertexIndices.length < 3) return false;
    
    // Calculate face normal
    final v0 = vertices[vertexIndices[0]];
    final v1 = vertices[vertexIndices[1]];
    final v2 = vertices[vertexIndices[2]];
    
    final edge1 = Vec3(v1.x - v0.x, v1.y - v0.y, v1.z - v0.z);
    final edge2 = Vec3(v2.x - v0.x, v2.y - v0.y, v2.z - v0.z);
    
    final normal = Vec3(
      edge1.y * edge2.z - edge1.z * edge2.y,
      edge1.z * edge2.x - edge1.x * edge2.z,
      edge1.x * edge2.y - edge1.y * edge2.x,
    );
    
    // Transform normal
    final transformedNormal = transform.transformVec3(normal);
    
    // Face is visible if normal points toward viewer (positive Z)
    return transformedNormal.z > 0;
  }
  
  double getDepth(List<ThreeDVertex> vertices) {
    double sumZ = 0;
    for (final idx in vertexIndices) {
      sumZ += vertices[idx].z;
    }
    return sumZ / vertexIndices.length;
  }
}

class Vec3 {
  double x, y, z;
  Vec3(this.x, this.y, this.z);
}

class ThreeDRenderer extends StatelessWidget {
  final ThreeDShape shape;
  final Size size;
  final double scale;

  const ThreeDRenderer({
    super.key,
    required this.shape,
    required this.size,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size,
      painter: _ThreeDPainter(shape: shape, scale: scale),
    );
  }
}

class _ThreeDPainter extends CustomPainter {
  final ThreeDShape shape;
  final double scale;

  _ThreeDPainter({required this.shape, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final transform = shape.transform.matrix;
    
    // Sort faces by depth (painter's algorithm)
    final sortedFaces = List<ThreeDFace>.from(shape.faces)
      ..sort((a, b) {
        final depthA = a.getDepth(shape.vertices);
        final depthB = b.getDepth(shape.vertices);
        return depthB.compareTo(depthA);
      });
    
    for (final face in sortedFaces) {
      // Skip back-facing faces
      if (!face.isVisible(shape.vertices, transform)) continue;
      
      final path = Path();
      bool first = true;
      
      for (final vertexIndex in face.vertexIndices) {
        final vertex = shape.vertices[vertexIndex];
        final projected = vertex.project(transform, size, scale);
        
        if (first) {
          path.moveTo(projected.dx, projected.dy);
          first = false;
        } else {
          path.lineTo(projected.dx, projected.dy);
        }
      }
      path.close();
      
      // Draw face with lighting
      final paint = Paint()
        ..color = face.color
        ..style = PaintingStyle.fill;
      
      canvas.drawPath(path, paint);
      
      // Draw edges
      final edgePaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      
      canvas.drawPath(path, edgePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 3D rotation animation
class ThreeDRotationAnimation extends StatefulWidget {
  final ThreeDShape shape;
  final Size size;
  final Duration duration;
  final bool autoPlay;

  const ThreeDRotationAnimation({
    super.key,
    required this.shape,
    required this.size,
    this.duration = const Duration(seconds: 10),
    this.autoPlay = true,
  });

  @override
  State<ThreeDRotationAnimation> createState() => _ThreeDRotationAnimationState();
}

class _ThreeDRotationAnimationState extends State<ThreeDRotationAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 0, end: 2 * pi).animate(_controller);
    
    if (widget.autoPlay) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final rotationY = _animation.value * 180 / pi;
        final rotationX = sin(_animation.value) * 20;
        
        final animatedShape = ThreeDShape(
          vertices: widget.shape.vertices,
          faces: widget.shape.faces,
          color: widget.shape.color,
          transform: ThreeDTransform(
            rotationX: rotationX,
            rotationY: rotationY,
            perspective: 800,
          ),
        );
        
        return ThreeDRenderer(
          shape: animatedShape,
          size: widget.size,
          scale: 1.5,
        );
      },
    );
  }
}

// Interactive 3D viewer
class Interactive3DViewer extends StatefulWidget {
  final ThreeDShape shape;
  final Size size;

  const Interactive3DViewer({
    super.key,
    required this.shape,
    required this.size,
  });

  @override
  State<Interactive3DViewer> createState() => _Interactive3DViewerState();
}

class _Interactive3DViewerState extends State<Interactive3DViewer> {
  double _rotationX = 0;
  double _rotationY = 0;
  double _lastPanX = 0;
  double _lastPanY = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        _lastPanX = details.localPosition.dx;
        _lastPanY = details.localPosition.dy;
      },
      onPanUpdate: (details) {
        setState(() {
          _rotationY += (details.localPosition.dx - _lastPanX) * 0.5;
          _rotationX += (details.localPosition.dy - _lastPanY) * 0.5;
          _lastPanX = details.localPosition.dx;
          _lastPanY = details.localPosition.dy;
        });
      },
      child: ThreeDRenderer(
        shape: ThreeDShape(
          vertices: widget.shape.vertices,
          faces: widget.shape.faces,
          color: widget.shape.color,
          transform: ThreeDTransform(
            rotationX: _rotationX,
            rotationY: _rotationY,
            perspective: 800,
          ),
        ),
        size: widget.size,
        scale: 1.5,
      ),
    );
  }
}

// Extension for Matrix4 to handle Vec3
extension Matrix4Vec3 on Matrix4 {
  Vec3 transformVec3(Vec3 vector) {
    final x = vector.x * this[0] + vector.y * this[4] + vector.z * this[8] + this[12];
    final y = vector.x * this[1] + vector.y * this[5] + vector.z * this[9] + this[13];
    final z = vector.x * this[2] + vector.y * this[6] + vector.z * this[10] + this[14];
    final w = vector.x * this[3] + vector.y * this[7] + vector.z * this[11] + this[15];
    
    if (w != 0 && w != 1) {
      return Vec3(x / w, y / w, z / w);
    }
    return Vec3(x, y, z);
  }
}
