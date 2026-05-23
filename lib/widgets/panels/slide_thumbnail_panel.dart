import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubit/editor_cubit.dart';
import '../../models/elements.dart';

class SlideThumbnailPanel extends StatelessWidget {
  const SlideThumbnailPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;

    return Container(
      color: const Color(0xFFF3F2F1),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'New Slide',
                  onPressed: cubit.addSlide,
                ),
                IconButton(
                  icon: const Icon(Icons.content_copy),
                  tooltip: 'Duplicate',
                  onPressed: () =>
                      cubit.duplicateSlide(state.presentation.activeSlideIndex),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete',
                  onPressed: () =>
                      cubit.deleteSlide(state.presentation.activeSlideIndex),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: state.presentation.slides.length,
              onReorder: cubit.reorderSlides,
              itemBuilder: (context, index) {
                final slide = state.presentation.slides[index];
                final isActive = index == state.presentation.activeSlideIndex;

                return GestureDetector(
                  key: ValueKey(slide.id),
                  onTap: () => cubit.selectSlide(index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isActive ? const Color(0xFFB7472A) : Colors.grey,
                        width: isActive ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Container(
                          color: slide.backgroundColorOverride ?? Colors.white,
                          child: Stack(
                            children: [
                              ...slide.elements.map((e) {
                                return Positioned(
                                  left: e.position.dx / 6,
                                  top: e.position.dy / 6,
                                  width: e.size.width / 6,
                                  height: e.size.height / 6,
                                  child: _buildMiniElement(e),
                                );
                              }),
                              if (slide.hidden)
                                Container(
                                  color: Colors.black.withOpacity(0.3),
                                  child: const Center(
                                    child: Icon(
                                      Icons.visibility_off,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniElement(SlideElement e) {
    if (e is TextElement) {
      return Container(
        color: e.fillColor,
        child: Text(
          e.paragraphs.isNotEmpty ? e.paragraphs.first.plainText : '',
          style: TextStyle(
            fontSize:
                (e.paragraphs.firstOrNull?.runs.firstOrNull?.fontSize ?? 18) /
                6,
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
              ? Border.all(color: e.strokeColor, width: 0.5)
              : null,
          borderRadius: e.shapeType == ShapeType.circle
              ? BorderRadius.circular(e.size.width / 12)
              : null,
        ),
      );
    } else if (e is ImageElement) {
      return Container(
        color: Colors.grey[300],
        child: const Icon(Icons.image, size: 12, color: Colors.grey),
      );
    }
    return const SizedBox();
  }
}
