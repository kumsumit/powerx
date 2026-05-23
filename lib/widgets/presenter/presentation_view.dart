import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart' hide SlideTransition;
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import '../../models/presentation.dart';
import '../../models/elements.dart';
import '../../models/table.dart' as pt;
import '../../models/chart.dart';
import '../shapes/shape_renderer.dart';
import '../tables/table_widget.dart';
import '../../engine/charts/advanced_charts.dart';
import '../animations/animation_engine.dart';
import '../ink/ink_canvas.dart';

class PresentationView extends StatefulWidget {
  final List<Slide> slides;
  final int initialIndex;
  final VoidCallback onExit;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const PresentationView({
    super.key,
    required this.slides,
    required this.initialIndex,
    required this.onExit,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<PresentationView> createState() => _PresentationViewState();
}

class _PresentationViewState extends State<PresentationView>
    with TickerProviderStateMixin {
  late int currentIndex;
  late AnimationController _transitionController;
  late Animation<double> _transitionAnimation;

  // Element animations controller
  late AnimationController _elementAnimController;
  int _playedAnimationsCount = 0;

  // Controls Overlay State
  bool _showControls = false;
  Timer? _hideControlsTimer;
  bool _showSlidePicker = false;

  // Laser Pointer State
  bool _laserEnabled = false;
  Offset? _laserPosition;
  final List<Offset> _laserTrail = [];
  Timer? _laserTrailTimer;

  // Slideshow Ink Annotation State
  bool _penEnabled = false;
  bool _eraserEnabled = false;
  Color _penColor = Colors.red;
  double _penThickness = 4.0;
  final List<InkStroke> _inkStrokes = [];

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;

    _transitionController = AnimationController(
      duration: widget.slides[currentIndex].transition.duration,
      vsync: this,
    );
    _transitionAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _transitionController, curve: Curves.easeInOut),
    );

    _elementAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _transitionController.forward(from: 0.0);
    _resetControlsTimer();

    // Start trail fade timer
    _laserTrailTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (_laserTrail.isNotEmpty) {
        setState(() {
          _laserTrail.removeAt(0);
        });
      }
    });
  }

  @override
  void dispose() {
    _transitionController.dispose();
    _elementAnimController.dispose();
    _hideControlsTimer?.cancel();
    _laserTrailTimer?.cancel();
    super.dispose();
  }

  void _resetControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_showControls && !_penEnabled && !_laserEnabled && !_showSlidePicker) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _onUserActivity() {
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _resetControlsTimer();
  }

  void _next() {
    final slide = widget.slides[currentIndex];
    final totalAnims = slide.animations.animations.length;

    if (_playedAnimationsCount < totalAnims) {
      setState(() {
        _playedAnimationsCount++;
      });
      _elementAnimController.forward(from: 0.0);
    } else {
      if (currentIndex < widget.slides.length - 1) {
        _transitionController.reverse().then((_) {
          if (mounted) {
            setState(() {
              currentIndex++;
              _playedAnimationsCount = 0;
              _inkStrokes.clear();
              widget.onNext();
            });
            _transitionController.duration =
                widget.slides[currentIndex].transition.duration;
            _transitionController.forward(from: 0.0);
          }
        });
      }
    }
  }

  void _prev() {
    if (_playedAnimationsCount > 0) {
      setState(() {
        _playedAnimationsCount--;
      });
      _elementAnimController.reverse();
    } else {
      if (currentIndex > 0) {
        _transitionController.reverse().then((_) {
          if (mounted) {
            setState(() {
              currentIndex--;
              // Start on the last animation of the previous slide
              _playedAnimationsCount =
                  widget.slides[currentIndex].animations.animations.length;
              _inkStrokes.clear();
              widget.onPrevious();
            });
            _transitionController.duration =
                widget.slides[currentIndex].transition.duration;
            _transitionController.forward(from: 0.0);
          }
        });
      }
    }
  }

  void _jumpToSlide(int index) {
    if (index >= 0 && index < widget.slides.length) {
      _transitionController.reverse().then((_) {
        if (mounted) {
          setState(() {
            currentIndex = index;
            _playedAnimationsCount = 0;
            _inkStrokes.clear();
            _showSlidePicker = false;
          });
          _transitionController.duration =
              widget.slides[currentIndex].transition.duration;
          _transitionController.forward(from: 0.0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slides[currentIndex];
    // A standard presentation aspect ratio 16:9
    const slideAspectRatio = 16.0 / 9.0;

    return RawKeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            _next();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.backspace) {
            _prev();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onExit();
          }
        }
      },
      child: MouseRegion(
        onHover: (details) {
          _onUserActivity();
          if (_laserEnabled) {
            setState(() {
              _laserPosition = details.localPosition;
              _laserTrail.add(details.localPosition);
              if (_laserTrail.length > 25) {
                _laserTrail.removeAt(0);
              }
            });
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Slide View area
              Center(
                child: AspectRatio(
                  aspectRatio: slideAspectRatio,
                  child: AnimatedBuilder(
                    animation: _transitionAnimation,
                    builder: (context, child) {
                      return SlideTransitionWidget(
                        transition: slide.transition,
                        animation: _transitionAnimation,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Container(
                            width: 960, // base design width
                            height: 540, // base design height (16:9)
                            color: slide.backgroundColorOverride ?? Colors.white,
                            child: Stack(
                              children: [
                                // Slide elements
                                ...slide.elements.map((e) => _buildElement(e, slide)),
                                // Slideshow Ink drawing canvas
                                if (_penEnabled || _inkStrokes.isNotEmpty)
                                  Positioned.fill(
                                    child: InkCanvas(
                                      strokes: _inkStrokes,
                                      currentColor: _penColor,
                                      currentThickness: _penThickness,
                                      isEraser: _eraserEnabled,
                                      canvasSize: const Size(960, 540),
                                      onStrokeComplete: (stroke) {
                                        setState(() {
                                          _inkStrokes.add(stroke);
                                        });
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Laser Pointer Trail Painter
              if (_laserEnabled && _laserPosition != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _LaserTrailPainter(
                        trail: _laserTrail,
                        position: _laserPosition!,
                      ),
                    ),
                  ),
                ),

              // Slide Picker Bottom Drawer
              if (_showSlidePicker) _buildSlidePicker(context),

              // Navigation controls overlay
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                bottom: _showControls ? 20 : -80,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildControlsBar(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Floating controls overlay bar
  Widget _buildControlsBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            tooltip: 'Previous',
            onPressed: _prev,
          ),
          Text(
            '${currentIndex + 1} / ${widget.slides.length}',
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
            tooltip: 'Next / Play Animation',
            onPressed: _next,
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 24, color: Colors.white24),
          const SizedBox(width: 8),
          
          // Laser Pointer toggle
          IconButton(
            icon: Icon(
              Icons.ads_click,
              color: _laserEnabled ? Colors.redAccent : Colors.white,
              size: 20,
            ),
            tooltip: 'Laser Pointer',
            onPressed: () {
              setState(() {
                _laserEnabled = !_laserEnabled;
                if (_laserEnabled) {
                  _penEnabled = false;
                }
              });
            },
          ),

          // Pen annotations toggle
          IconButton(
            icon: Icon(
              Icons.edit,
              color: _penEnabled ? Colors.blueAccent : Colors.white,
              size: 20,
            ),
            tooltip: 'Draw on Slide',
            onPressed: () {
              setState(() {
                _penEnabled = !_penEnabled;
                if (_penEnabled) {
                  _laserEnabled = false;
                  _eraserEnabled = false;
                }
              });
            },
          ),

          if (_penEnabled) ...[
            _buildColorDot(Colors.red),
            _buildColorDot(Colors.yellow),
            _buildColorDot(Colors.green),
            _buildColorDot(Colors.blue),
            IconButton(
              icon: Icon(
                Icons.cleaning_services,
                color: _eraserEnabled ? Colors.orangeAccent : Colors.white70,
                size: 18,
              ),
              tooltip: 'Eraser',
              onPressed: () {
                setState(() => _eraserEnabled = !_eraserEnabled);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 18),
              tooltip: 'Clear Drawings',
              onPressed: () {
                setState(() => _inkStrokes.clear());
              },
            ),
          ],

          // Slide drawer picker toggle
          IconButton(
            icon: Icon(
              Icons.grid_view,
              color: _showSlidePicker ? Colors.tealAccent : Colors.white,
              size: 20,
            ),
            tooltip: 'All Slides',
            onPressed: () {
              setState(() {
                _showSlidePicker = !_showSlidePicker;
                if (_showSlidePicker) {
                  _showControls = true;
                }
              });
            },
          ),

          const SizedBox(width: 8),
          Container(width: 1, height: 24, color: Colors.white24),
          const SizedBox(width: 8),

          IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
            tooltip: 'Exit Slide Show',
            onPressed: widget.onExit,
          ),
        ],
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    final isSelected = _penColor == color && !_eraserEnabled;
    return GestureDetector(
      onTap: () {
        setState(() {
          _penColor = color;
          _eraserEnabled = false;
          _penEnabled = true;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black26, blurRadius: 2, spreadRadius: 1)]
              : null,
        ),
      ),
    );
  }

  // Slide picker horizontal grid at the bottom
  Widget _buildSlidePicker(BuildContext context) {
    return Positioned(
      bottom: _showControls ? 80 : 20,
      left: 20,
      right: 20,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Slide',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.slides.length,
                itemBuilder: (context, index) {
                  final slide = widget.slides[index];
                  final isCurrent = index == currentIndex;
                  return GestureDetector(
                    onTap: () => _jumpToSlide(index),
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isCurrent ? Colors.tealAccent : Colors.white24,
                          width: isCurrent ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              color: slide.backgroundColorOverride ?? Colors.white,
                              child: Stack(
                                children: slide.elements.map((e) {
                                  // Draw tiny elements for picker
                                  return Positioned(
                                    left: e.position.dx * (120 / 960),
                                    top: e.position.dy * (67.5 / 540),
                                    width: e.size.width * (120 / 960),
                                    height: e.size.height * (67.5 / 540),
                                    child: Container(
                                      color: e is TextElement
                                          ? (e.fillColor ?? Colors.grey.withOpacity(0.2))
                                          : e is ShapeElement
                                              ? e.fillColor
                                              : Colors.blue.withOpacity(0.2),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              color: Colors.black54,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builder for slide elements that uses fully featured custom widgets
  Widget _buildElement(SlideElement e, Slide slide) {
    Widget elementWidget;

    if (e is TextElement) {
      elementWidget = Container(
        color: e.fillColor,
        padding: e.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: e.paragraphs.map((para) {
            return RichText(
              text: TextSpan(
                children: para.runs.map((run) {
                  return TextSpan(
                    text: run.text,
                    style: TextStyle(
                      fontFamily: run.fontFamily,
                      fontSize: run.fontSize,
                      color: run.color,
                      fontWeight: run.bold ? FontWeight.bold : FontWeight.normal,
                      fontStyle: run.italic ? ui.FontStyle.italic : ui.FontStyle.normal,
                      decoration: run.underline
                          ? TextDecoration.underline
                          : run.strikethrough
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ),
      );
    } else if (e is ShapeElement) {
      elementWidget = ShapeRenderer(shape: e);
    } else if (e is ImageElement) {
      elementWidget = e.imagePath.isEmpty
          ? Container(
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.image, color: Colors.grey)),
            )
          : Image.file(
              File(e.imagePath),
              fit: _mapFillMode(e.fillMode),
              width: e.size.width,
              height: e.size.height,
            );
    } else if (e is pt.TableElement) {
      elementWidget = TableWidget(table: e);
    } else if (e is ChartElement) {
      final rows = e.data.series.map((s) => s.values).toList();
      final dataTable = ChartDataTable(
        rowHeaders: e.data.series.map((s) => s.name).toList(),
        columnHeaders: e.data.categories,
        data: rows,
        seriesColors: e.data.series.map((s) => s.color).toList(),
      );
      elementWidget = Container(
        color: e.style.backgroundColor,
        child: AdvancedChartRenderer(
          type: _mapChartType(e.type),
          data: dataTable,
          size: e.size,
          showLegend: e.hasLegend,
          title: e.hasTitle ? e.title : null,
        ),
      );
    } else if (e is InkElement) {
      elementWidget = CustomPaint(
        size: e.size,
        painter: _InkElementPainter(
          points: e.points,
          color: e.color,
          thickness: e.thickness,
          isHighlighter: e.isHighlighter,
          opacity: e.opacity,
        ),
      );
    } else if (e is GroupElement) {
      elementWidget = Stack(
        clipBehavior: Clip.none,
        children: e.children.map((child) {
          return Positioned(
            left: child.position.dx - e.position.dx,
            top: child.position.dy - e.position.dy,
            width: child.size.width,
            height: child.size.height,
            child: _buildElement(child, slide),
          );
        }).toList(),
      );
    } else {
      elementWidget = const SizedBox();
    }

    // Wrap the element in slide-level animations
    final elementAnims =
        slide.animations.animations.where((a) => a.targetElementId == e.id).toList();

    Widget animatedWidget = AnimationEngine.buildAnimatedElement(
      element: e,
      animations: elementAnims,
      controller: _elementAnimController,
      isPlaying: elementAnims.isNotEmpty,
      triggerIndex: _playedAnimationsCount - 1,
      child: elementWidget,
    );

    return Positioned(
      left: e.position.dx,
      top: e.position.dy,
      width: e.size.width,
      height: e.size.height,
      child: Transform.rotate(
        angle: e.rotation * pi / 180,
        child: animatedWidget,
      ),
    );
  }

  BoxFit _mapFillMode(ImageFillMode mode) {
    switch (mode) {
      case ImageFillMode.stretch:
        return BoxFit.fill;
      case ImageFillMode.fit:
        return BoxFit.contain;
      case ImageFillMode.fill:
        return BoxFit.cover;
      default:
        return BoxFit.contain;
    }
  }

  AdvancedChartType _mapChartType(ChartType t) {
    switch (t) {
      case ChartType.bar:
        return AdvancedChartType.barClustered;
      case ChartType.line:
        return AdvancedChartType.line;
      case ChartType.pie:
        return AdvancedChartType.pie;
      default:
        return AdvancedChartType.columnClustered;
    }
  }
}

// Painter for glowing laser pointer trail
class _LaserTrailPainter extends CustomPainter {
  final List<Offset> trail;
  final Offset position;

  _LaserTrailPainter({required this.trail, required this.position});

  @override
  void paint(Canvas canvas, Size size) {
    if (trail.isNotEmpty) {
      final path = Path();
      path.moveTo(trail.first.dx, trail.first.dy);
      for (int i = 1; i < trail.length; i++) {
        path.lineTo(trail[i].dx, trail[i].dy);
      }

      // Draw faint glow trail
      final trailPaint = Paint()
        ..color = Colors.red.withOpacity(0.2)
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, trailPaint);

      final tightTrailPaint = Paint()
        ..color = Colors.red.withOpacity(0.5)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, tightTrailPaint);
    }

    // Draw glowing laser dot
    final outerGlow = Paint()
      ..color = Colors.red.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 8.0, outerGlow);

    final innerCore = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 3.0, innerCore);

    final redCore = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 2.0, redCore);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Painter for drawing InkElement on Slide
class _InkElementPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double thickness;
  final bool isHighlighter;
  final double opacity;

  _InkElementPainter({
    required this.points,
    required this.color,
    required this.thickness,
    required this.isHighlighter,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = isHighlighter
          ? color.withOpacity(0.3)
          : color.withOpacity(opacity)
      ..strokeWidth = isHighlighter ? thickness * 3 : thickness
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (isHighlighter) {
      paint.blendMode = BlendMode.multiply;
    }

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
