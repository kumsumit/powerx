import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/editor_cubit.dart';
import 'ribbon/ribbon.dart';
import 'canvas/canvas_area.dart';
import 'panels/slide_thumbnail_panel.dart';
import 'panels/properties_panel.dart';
import 'presenter/presentation_view.dart';
import 'presenter/presenter_view.dart';

class EditorShell extends StatelessWidget {
  const EditorShell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorCubit, EditorState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.errorMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Dismiss',
                  onPressed: context.read<EditorCubit>().clearError,
                ),
              ),
            );
          });
        }

        if (state.isPresentationMode) {
          if (state.isPresenterView) {
            return PresenterView(
              presentation: state.presentation,
              initialIndex: state.presentation.activeSlideIndex,
              onExit: () => context.read<EditorCubit>().exitPresentation(),
            );
          }
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
                    const SizedBox(width: 260, child: SlideThumbnailPanel()),
                    const VerticalDivider(width: 1),
                    Expanded(child: CanvasArea(zoom: state.canvasZoom)),
                    const VerticalDivider(width: 1),
                    SizedBox(width: 300, child: PropertiesPanel()),
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

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    return Container(
      height: 32,
      color: const Color(0xFFF3F2F1),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(
            'Slide ${state.presentation.activeSlideIndex + 1} of ${state.presentation.slides.length}',
            style: const TextStyle(fontSize: 12),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.undo, size: 18),
            tooltip: 'Undo',
            onPressed: state.canUndo ? cubit.undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo, size: 18),
            tooltip: 'Redo',
            onPressed: state.canRedo ? cubit.redo : null,
          ),
          const VerticalDivider(),
          SizedBox(
            width: 80,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<double>(
                value: state.canvasZoom,
                isDense: true,
                items: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0].map((
                  z,
                ) {
                  return DropdownMenuItem(
                    value: z,
                    child: Text('${(z * 100).toInt()}%'),
                  );
                }).toList(),
                onChanged: (v) => v != null ? cubit.setZoom(v) : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => cubit.startPresentation(),
            icon: const Icon(Icons.slideshow, size: 16),
            label: const Text('Slide Show'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB7472A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => cubit.startPresentation(presenterView: true),
            icon: const Icon(Icons.present_to_all, size: 16),
            label: const Text('Presenter View'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4472C4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }
}
