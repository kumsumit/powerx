import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/editor_cubit.dart';
import '../utils/shortcut_manager.dart';
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
                content: Text(
                  state.errorMessage!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                behavior: SnackBarBehavior.floating,
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
            presentation: state.presentation,
            initialIndex: state.presentation.activeSlideIndex,
            onExit: () => context.read<EditorCubit>().exitPresentation(),
            onNext: () => context.read<EditorCubit>().nextSlide(),
            onPrevious: () => context.read<EditorCubit>().previousSlide(),
          );
        }

        final cubit = context.read<EditorCubit>();
        return EditorShortcuts(
          shortcuts: {
            EditorShortcutActivators.ctrlZ: cubit.undo,
            EditorShortcutActivators.ctrlY: cubit.redo,
            EditorShortcutActivators.ctrlShiftZ: cubit.redo,
            EditorShortcutActivators.ctrlN: cubit.newPresentation,
            EditorShortcutActivators.ctrlC: () {
              final id = cubit.state.selectedElementId;
              if (id != null) cubit.copyElement(id);
            },
            EditorShortcutActivators.ctrlV: cubit.pasteElement,
            EditorShortcutActivators.ctrlX: () {
              final id = cubit.state.selectedElementId;
              if (id != null) cubit.cutElement(id);
            },
            EditorShortcutActivators.ctrlD: () {
              final id = cubit.state.selectedElementId;
              if (id != null) cubit.copyElement(id);
              cubit.pasteElement();
            },
            EditorShortcutActivators.delete: cubit.deleteSelected,
            EditorShortcutActivators.backspace: cubit.deleteSelected,
            EditorShortcutActivators.escape: () => cubit.selectElement(null),
            EditorShortcutActivators.f5: cubit.startPresentation,
            EditorShortcutActivators.shiftF5: () =>
                cubit.startPresentation(presenterView: true),
          },
          child: Scaffold(
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 900;
                  final isVeryCompact = constraints.maxWidth < 600;

                  return Column(
                    children: [
                      const Ribbon(),
                      Expanded(
                        child: Row(
                          children: [
                            if (!isVeryCompact) ...[
                              SizedBox(
                                width: isCompact ? 72 : 260,
                                child: const SlideThumbnailPanel(),
                              ),
                              VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: Colors.grey.shade200,
                              ),
                            ],
                            Expanded(child: CanvasArea(zoom: state.canvasZoom)),
                            if (!isCompact) ...[
                              VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: Colors.grey.shade200,
                              ),
                              const SizedBox(
                                width: 300,
                                child: PropertiesPanel(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const StatusBar(),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _PresentationAction { slideShow, presenterView }

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;

          return Row(
            children: [
              Flexible(
                child: Text(
                  'Slide ${state.presentation.activeSlideIndex + 1} of ${state.presentation.slides.length}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
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
                width: isCompact ? 70 : 90,
                child: PopupMenuButton<double>(
                  initialValue: state.canvasZoom,
                  tooltip: 'Zoom',
                  constraints: const BoxConstraints(
                    maxHeight: 280,
                    minWidth: 90,
                  ),
                  onSelected: cubit.setZoom,
                  itemBuilder: (context) {
                    final list = [
                      0.25,
                      0.5,
                      0.75,
                      1.0,
                      1.25,
                      1.5,
                      2.0,
                      3.0,
                      4.0,
                    ];
                    if (!list.contains(state.canvasZoom)) {
                      list.add(state.canvasZoom);
                      list.sort();
                    }
                    return list.map((z) {
                      return PopupMenuItem<double>(
                        value: z,
                        child: Text('${(z * 100).toInt()}%'),
                      );
                    }).toList();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: Text('${(state.canvasZoom * 100).toInt()}%'),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isCompact)
                PopupMenuButton<_PresentationAction>(
                  tooltip: 'Presentation',
                  icon: const Icon(Icons.slideshow, size: 18),
                  onSelected: (action) {
                    switch (action) {
                      case _PresentationAction.slideShow:
                        cubit.startPresentation();
                        break;
                      case _PresentationAction.presenterView:
                        cubit.startPresentation(presenterView: true);
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _PresentationAction.slideShow,
                      child: Text('Slide Show'),
                    ),
                    PopupMenuItem(
                      value: _PresentationAction.presenterView,
                      child: Text('Presenter View'),
                    ),
                  ],
                )
              else ...[
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
            ],
          );
        },
      ),
    );
  }
}
