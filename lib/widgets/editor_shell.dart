import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/editor_cubit.dart';
import '../models/presentation.dart';
import 'canvas_area.dart';
import 'slide_thumbnail_panel.dart';
import 'ribbon.dart';

class EditorShell extends StatelessWidget {
  const EditorShell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorCubit, EditorState>(
      builder: (context, state) {
        if (state.isPresentationMode) {
          return PresentationView(
            slides: state.presentation.slides,
            initialIndex: state.presentation.activeSlideIndex,
            onExit: () => context.read<EditorCubit>().exitPresentation(),
            onNext: () => context.read<EditorCubit>().nextSlide(),
            onPrevious: () => context.read<EditorCubit>().previousSlide(),
          );
        }

        return Scaffold(
          body: Column(
            children: [
              const Ribbon(),
              Expanded(
                child: Row(
                  children: [
                    const SizedBox(
                      width: 240,
                      child: SlideThumbnailPanel(),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: CanvasArea(zoom: state.canvasZoom),
                    ),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 240,
                      child: PropertiesPanel(),
                    ),
                  ],
                ),
              ),
              const StatusBar(),
            ],
          ),
        );
      },
    );
  }
}

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

class _PresentationViewState extends State<PresentationView> {
  late int currentIndex;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  void _next() {
    if (currentIndex < widget.slides.length - 1) {
      setState(() {
        _isAnimating = true;
        currentIndex++;
      });
      widget.onNext();
    }
  }

  void _prev() {
    if (currentIndex > 0) {
      setState(() {
        _isAnimating = true;
        currentIndex--;
      });
      widget.onPrevious();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _next,
      onSecondaryTap: _prev,
      child: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
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
          backgroundColor: Colors.black,
          body: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: widget.slides[currentIndex].backgroundColor,
                child: Stack(
                  children: [
                    ...widget.slides[currentIndex].elements.map((e) => _buildElement(e)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildElement(SlideElement e) {
    return Positioned(
      left: e.position.dx,
      top: e.position.dy,
      width: e.size.width,
      height: e.size.height,
      child: Transform.rotate(
        angle: e.rotation,
        child: e is TextElement
            ? Text(
                e.text,
                style: e.style,
                textAlign: e.align,
              )
            : e is ShapeElement
                ? Container(
                    decoration: BoxDecoration(
                      color: e.fillColor,
                      border: Border.all(color: e.strokeColor, width: e.strokeWidth),
                      borderRadius: e.shapeType == ShapeType.circle
                          ? BorderRadius.circular(e.size.width / 2)
                          : null,
                    ),
                  )
                : const SizedBox(),
      ),
    );
  }
}

class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorCubit>().state;
    final selectedId = state.selectedElementId;
    if (selectedId == null) {
      return const Center(child: Text('Select an element'));
    }

    final element = state.activeSlide.elements.firstWhere((e) => e.id == selectedId);
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Properties', style: TextStyle(fontWeight: FontWeight.bold)),
          const Divider(),
          if (element is TextElement) ...[
            const Text('Text Content'),
            TextField(
              controller: TextEditingController(text: element.text),
              onChanged: (val) {
                context.read<EditorCubit>().updateElement(
                      element.copyWith(text: val),
                    );
              },
              maxLines: 3,
            ),
          ],
          if (element is ShapeElement) ...[
            Material(
              color: Colors.transparent,
              child: ListTile(
                title: const Text('Fill Color'),
                trailing: CircleAvatar(backgroundColor: element.fillColor, radius: 12),
                onTap: () async {
                  // Show color picker in real app
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    return Container(
      height: 28,
      color: const Color(0xFFF3F2F1),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text('Slide ${state.presentation.activeSlideIndex + 1} of ${state.presentation.slides.length}'),
          const Spacer(),
          Text('${(state.canvasZoom * 100).toInt()}%'),
          IconButton(
            icon: const Icon(Icons.slideshow, size: 16),
            tooltip: 'Slide Show',
            onPressed: cubit.startPresentation,
          ),
        ],
      ),
    );
  }
}