import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/presentation.dart';
import '../../models/elements.dart';

class PresenterView extends StatefulWidget {
  final Presentation presentation;
  final int initialIndex;
  final VoidCallback onExit;

  const PresenterView({
    super.key,
    required this.presentation,
    required this.initialIndex,
    required this.onExit,
  });

  @override
  State<PresenterView> createState() => _PresenterViewState();
}

class _PresenterViewState extends State<PresenterView> {
  late int currentIndex;
  late Timer _timer;
  Duration _elapsed = Duration.zero;
  bool _showTimer = true;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed += const Duration(seconds: 1);
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _next() {
    if (currentIndex < widget.presentation.slides.length - 1) {
      setState(() => currentIndex++);
    }
  }

  void _prev() {
    if (currentIndex > 0) {
      setState(() => currentIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.presentation.slides[currentIndex];
    final nextSlide = currentIndex < widget.presentation.slides.length - 1
        ? widget.presentation.slides[currentIndex + 1]
        : null;

    return RawKeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.space) {
            _next();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _prev();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onExit();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1a1a1a),
        body: Row(
          children: [
            // Left: Current slide large
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          color: slide.backgroundColorOverride ?? Colors.white,
                          child: Stack(
                            children: slide.elements
                                .map((e) => _buildElement(e))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Notes section
                  Container(
                    height: 200,
                    color: const Color(0xFF2a2a2a),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Speaker Notes',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(
                              text: slide.notes ?? '',
                            ),
                            style: const TextStyle(color: Colors.white70),
                            maxLines: null,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Add notes...',
                              hintStyle: TextStyle(color: Colors.white30),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Right: Controls and next slide
            Container(
              width: 300,
              color: const Color(0xFF2a2a2a),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timer
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a1a1a),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.timer, color: Colors.white),
                          onPressed: () =>
                              setState(() => _showTimer = !_showTimer),
                        ),
                        if (_showTimer)
                          Text(
                            '${_elapsed.inMinutes.toString().padLeft(2, '0')}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontFamily: 'monospace',
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Slide counter
                  Text(
                    'Slide ${currentIndex + 1} of ${widget.presentation.slides.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  // Next slide preview
                  const Text(
                    'Next Slide',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (nextSlide != null)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        color:
                            nextSlide.backgroundColorOverride ?? Colors.white,
                        child: Stack(
                          children: nextSlide.elements
                              .map((e) => _buildElement(e, scale: 0.3))
                              .toList(),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 150,
                      color: const Color(0xFF1a1a1a),
                      child: const Center(
                        child: Text(
                          'End of presentation',
                          style: TextStyle(color: Colors.white30),
                        ),
                      ),
                    ),
                  const Spacer(),
                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: _prev,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                        ),
                        onPressed: _next,
                      ),
                      IconButton(
                        icon: const Icon(Icons.exit_to_app, color: Colors.red),
                        onPressed: widget.onExit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElement(SlideElement e, {double scale = 1.0}) {
    return Positioned(
      left: e.position.dx * scale,
      top: e.position.dy * scale,
      width: e.size.width * scale,
      height: e.size.height * scale,
      child: Transform.rotate(
        angle: e.rotation * pi / 180,
        child: e is TextElement
            ? Container(
                color: e.fillColor,
                padding: EdgeInsets.all(e.padding.left * scale),
                child: Text(
                  e.paragraphs.map((p) => p.plainText).join('\n'),
                  style: TextStyle(
                    fontSize:
                        (e.paragraphs.firstOrNull?.runs.firstOrNull?.fontSize ??
                            18) *
                        scale,
                    color:
                        e.paragraphs.firstOrNull?.runs.firstOrNull?.color ??
                        Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : e is ShapeElement
            ? Container(
                decoration: BoxDecoration(
                  color: e.fillColor,
                  border: e.strokeWidth > 0
                      ? Border.all(
                          color: e.strokeColor,
                          width: e.strokeWidth * scale,
                        )
                      : null,
                  borderRadius: e.shapeType == ShapeType.circle
                      ? BorderRadius.circular(e.size.width * scale / 2)
                      : null,
                ),
              )
            : e is ImageElement
            ? Container(
                color: Colors.grey[300],
                child: const Icon(Icons.image, size: 24, color: Colors.grey),
              )
            : const SizedBox(),
      ),
    );
  }
}
