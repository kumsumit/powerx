import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/editor_cubit.dart';
import '../models/presentation.dart';

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
          Expanded(
            child: ListView.builder(
              itemCount: state.presentation.slides.length,
              itemBuilder: (context, index) {
                final isActive = index == state.presentation.activeSlideIndex;
                return GestureDetector(
                  onTap: () => cubit.selectSlide(index),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isActive ? const Color(0xFFB7472A) : Colors.grey,
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        color: state.presentation.slides[index].backgroundColor,
                        child: Stack(
                          children: state.presentation.slides[index].elements.map((e) {
                            return Positioned(
                              left: e.position.dx / 5,
                              top: e.position.dy / 5,
                              width: e.size.width / 5,
                              height: e.size.height / 5,
                              child: e is TextElement
                                  ? Text(e.text, style: TextStyle(fontSize: e.style.fontSize! / 5))
                                  : e is ShapeElement
                                      ? Container(color: e.fillColor)
                                      : const SizedBox(),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: cubit.addSlide,
                  icon: const Icon(Icons.add),
                  label: const Text('New Slide'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => cubit.deleteSlide(state.presentation.activeSlideIndex),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}