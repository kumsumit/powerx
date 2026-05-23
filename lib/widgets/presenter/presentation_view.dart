import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/presentation.dart';
import '../../models/elements.dart';
import '../../models/animation.dart';

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
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _controller = AnimationController(
      duration: widget.slides[currentIndex].transition.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (currentIndex < widget.slides.length - 1) {
      _controller.reverse().then((_) {
        setState(() {
          currentIndex++;
          widget.onNext();
        });
        _controller.duration = widget.slides[currentIndex].transition.duration;
        _controller.forward();
      });
    }
  }

  void _prev() {
    if (currentIndex > 0) {
      _controller.reverse().then((_) {
        setState(() {
          currentIndex--;
          widget.onPrevious();
        });
        _controller.duration = widget.slides[currentIndex].transition.duration;
        _controller.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            _next();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _prev();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onExit();
          }
        }
      },
      child: GestureDetector(
        onTap: _next,
        onSecondaryTap: _prev,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final slide = widget.slides[currentIndex];
                return _buildTransition(
                  slide.transition.type,
                  _animation.value,
                  AspectRatio(
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransition(TransitionType type, double value, Widget child) {
    switch (type) {
      case TransitionType.fade:
        return Opacity(opacity: value, child: child);
      case TransitionType.push:
        return Transform.translate(
          offset: Offset((1 - value) * MediaQuery.of(context).size.width, 0),
          child: child,
        );
      case TransitionType.wipe:
        return ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: child,
          ),
        );
      default:
        return child;
    }
  }

  Widget _buildElement(SlideElement e) {
    return Positioned(
      left: e.position.dx,
      top: e.position.dy,
      width: e.size.width,
      height: e.size.height,
      child: Transform.rotate(
        angle: e.rotation * pi / 180,
        child: e is TextElement
            ? Container(
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
                              fontWeight: run.bold
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontStyle: run.italic
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                ),
              )
            : e is ShapeElement
            ? Container(
                decoration: BoxDecoration(
                  color: e.fillColor,
                  border: e.strokeWidth > 0
                      ? Border.all(color: e.strokeColor, width: e.strokeWidth)
                      : null,
                  borderRadius: e.shapeType == ShapeType.circle
                      ? BorderRadius.circular(e.size.width / 2)
                      : null,
                ),
              )
            : e is ImageElement
            ? Image.file(
                File(e.imagePath),
                fit: BoxFit.fill,
                width: e.size.width,
                height: e.size.height,
              )
            : const SizedBox(),
      ),
    );
  }
}
