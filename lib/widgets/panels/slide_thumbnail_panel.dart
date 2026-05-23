import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubit/editor_cubit.dart';
import '../../models/elements.dart';
import '../slide_background.dart';

class SlideThumbnailPanel extends StatelessWidget {
  const SlideThumbnailPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;

    return Container(
      color: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _PanelActionButton(
                  icon: Icons.add,
                  tooltip: 'New Slide',
                  onPressed: cubit.addSlide,
                  color: const Color(0xFFB7472A),
                ),
                _PanelActionButton(
                  icon: Icons.copy,
                  tooltip: 'Duplicate',
                  onPressed: () =>
                      cubit.duplicateSlide(state.presentation.activeSlideIndex),
                  color: Colors.blue.shade700,
                ),
                _PanelActionButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  onPressed: () =>
                      cubit.deleteSlide(state.presentation.activeSlideIndex),
                  color: Colors.red.shade700,
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: state.presentation.slides.length,
              onReorder: cubit.reorderSlides,
              itemBuilder: (context, index) {
                final slide = state.presentation.slides[index];
                final isActive = index == state.presentation.activeSlideIndex;

                return Container(
                  key: ValueKey(slide.id),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      // Left drag handle and index
                      ReorderableDragStartListener(
                        index: index,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? const Color(0xFFB7472A)
                                      : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Icon(
                                Icons.drag_indicator,
                                size: 14,
                                color: isActive
                                    ? const Color(0xFFB7472A)
                                    : Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Slide thumbnail preview
                      Expanded(
                        child: GestureDetector(
                          onTap: () => cubit.selectSlide(index),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFFB7472A)
                                    : Colors.grey.shade300,
                                width: isActive ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFB7472A,
                                        ).withOpacity(0.15),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                            ),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: SlideBackground(
                                  color: slide.backgroundColorOverride,
                                  fill: slide.backgroundFillOverride,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final slideSize =
                                          state.presentation.settings.slideSize;
                                      final scaleX =
                                          constraints.maxWidth /
                                          slideSize.width;
                                      final scaleY =
                                          constraints.maxHeight /
                                          slideSize.height;
                                      final avgScale = (scaleX + scaleY) / 2;

                                      return Stack(
                                        children: [
                                          ...slide.elements.map((e) {
                                            return Positioned(
                                              left: e.position.dx * scaleX,
                                              top: e.position.dy * scaleY,
                                              width: e.size.width * scaleX,
                                              height: e.size.height * scaleY,
                                              child: _buildMiniElement(
                                                e,
                                                avgScale,
                                              ),
                                            );
                                          }),
                                          if (slide.hidden)
                                            Container(
                                              color: Colors.black.withOpacity(
                                                0.3,
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.visibility_off,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniElement(SlideElement e, double scale) {
    if (e is TextElement) {
      return Container(
        color: e.fillColor,
        child: Text(
          e.paragraphs.isNotEmpty ? e.paragraphs.first.plainText : '',
          style: TextStyle(
            fontSize:
                ((e.paragraphs.firstOrNull?.runs.firstOrNull?.fontSize ?? 18) *
                        scale)
                    .clamp(2.0, 100.0),
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      );
    } else if (e is ShapeElement) {
      return Container(
        decoration: BoxDecoration(
          color: e.fillColor,
          border: e.strokeWidth > 0
              ? Border.all(
                  color: e.strokeColor,
                  width: (e.strokeWidth * scale).clamp(0.1, 10.0),
                )
              : null,
          borderRadius: e.shapeType == ShapeType.circle
              ? BorderRadius.circular(e.size.width * scale / 2)
              : null,
        ),
      );
    } else if (e is ImageElement) {
      return Container(
        color: Colors.grey[300],
        child: const Icon(Icons.image, size: 10, color: Colors.grey),
      );
    } else if (e is InkElement) {
      return CustomPaint(
        painter: _MiniInkPainter(
          points: e.points,
          color: e.color,
          thickness: e.thickness * scale,
          scale: scale,
        ),
      );
    }
    return const SizedBox();
  }
}

class _PanelActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  const _PanelActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

class _MiniInkPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double thickness;
  final double scale;

  _MiniInkPainter({
    required this.points,
    required this.color,
    required this.thickness,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (int i = 1; i < points.length; i++) {
      canvas.drawLine(points[i - 1] * scale, points[i] * scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
