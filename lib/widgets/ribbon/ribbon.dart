import 'package:flutter/material.dart' hide SlideTransition;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_color_picker_plus/flutter_color_picker_plus.dart';
import '../../cubit/editor_cubit.dart';
import '../../models/animation.dart';
import '../../models/chart.dart';

class Ribbon extends StatefulWidget {
  const Ribbon({super.key});

  @override
  State<Ribbon> createState() => _RibbonState();
}

class _RibbonState extends State<Ribbon> {
  // 0=File(popup), 1=Home, 2=Insert, 3=Design, 4=Transitions, 5=Animations, 6=Slide Show, 7=View
  int _activeTab = 1;

  static const _tabLabels = [
    'File', 'Home', 'Insert', 'Design',
    'Transitions', 'Animations', 'Slide Show', 'View',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 124,
      color: const Color(0xFFB7472A),
      child: Column(
        children: [
          _buildTabBar(context),
          Expanded(
            child: Container(
              color: const Color(0xFFF3F2F1),
              child: _buildToolbar(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          for (int i = 0; i < _tabLabels.length; i++)
            _Tab(
              label: _tabLabels[i],
              isActive: _activeTab == i,
              onTap: () {
                if (i == 0) {
                  _showFileMenu(context);
                } else {
                  setState(() => _activeTab = i);
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    switch (_activeTab) {
      case 1: return _HomeToolbar();
      case 2: return _InsertToolbar();
      case 3: return _DesignToolbar();
      case 4: return _TransitionsToolbar();
      case 5: return _AnimationsToolbar();
      case 6: return _SlideShowToolbar();
      case 7: return _ViewToolbar();
      default: return _HomeToolbar();
    }
  }

  void _showFileMenu(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('New'),
                onTap: () {
                  cubit.newPresentation();
                  Navigator.pop(dialogCtx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Open…'),
                onTap: () async {
                  Navigator.pop(dialogCtx);
                  final result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pptx'],
                  );
                  if (result != null) {
                    final path = result.files.single.path;
                    if (path != null) cubit.openPresentation(path);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.save),
                title: const Text('Save'),
                onTap: () async {
                  Navigator.pop(dialogCtx);
                  final path = cubit.state.presentation.filePath;
                  if (path != null) {
                    cubit.savePresentation(path);
                  } else {
                    _doSaveAs(cubit);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.save_as),
                title: const Text('Save As…'),
                onTap: () async {
                  Navigator.pop(dialogCtx);
                  _doSaveAs(cubit);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Close'),
                onTap: () {
                  Navigator.pop(dialogCtx);
                  cubit.newPresentation();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doSaveAs(EditorCubit cubit) async {
    final savePath = await FilePicker.saveFile(
      fileName: '${cubit.state.presentation.title}.pptx',
      type: FileType.custom,
      allowedExtensions: ['pptx'],
    );
    if (savePath != null) {
      final path = savePath.endsWith('.pptx') ? savePath : '$savePath.pptx';
      cubit.savePresentation(path);
    }
  }
}

// ── Home Tab ───────────────────────────────────────────────────────────────────

class _HomeToolbar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    final tool = state.activeTool;
    final selId = state.selectedElementId;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToolGroup(label: 'Clipboard', children: [
            _ToolButton(icon: Icons.paste, label: 'Paste', onTap: cubit.pasteElement),
            _ToolButton(icon: Icons.content_cut, label: 'Cut', onTap: selId != null ? () => cubit.cutElement(selId) : null),
            _ToolButton(icon: Icons.content_copy, label: 'Copy', onTap: selId != null ? () => cubit.copyElement(selId) : null),
          ]),
          const _VDiv(),
          _ToolGroup(label: 'History', children: [
            _ToolButton(icon: Icons.undo, label: 'Undo', onTap: state.canUndo ? cubit.undo : null),
            _ToolButton(icon: Icons.redo, label: 'Redo', onTap: state.canRedo ? cubit.redo : null),
          ]),
          const _VDiv(),
          _ToolGroup(label: 'Slides', children: [
            _ToolButton(icon: Icons.add_box, label: 'New', onTap: cubit.addSlide),
            _ToolButton(icon: Icons.copy_all, label: 'Duplicate', onTap: () => cubit.duplicateSlide(state.presentation.activeSlideIndex)),
            _ToolButton(icon: Icons.delete_outline, label: 'Delete', onTap: () => cubit.deleteSlide(state.presentation.activeSlideIndex)),
          ]),
          const _VDiv(),
          _ToolGroup(label: 'Drawing', children: [
            _ToolButton(icon: Icons.near_me, label: 'Select', isActive: tool == Tool.select, onTap: () => cubit.setTool(Tool.select)),
            _ToolButton(icon: Icons.text_fields, label: 'Text', isActive: tool == Tool.textBox, onTap: () => cubit.setTool(Tool.textBox)),
            _ToolButton(icon: Icons.rectangle_outlined, label: 'Rect', isActive: tool == Tool.rectangle, onTap: () => cubit.setTool(Tool.rectangle)),
            _ToolButton(icon: Icons.rounded_corner, label: 'Rounded', isActive: tool == Tool.roundedRectangle, onTap: () => cubit.setTool(Tool.roundedRectangle)),
            _ToolButton(icon: Icons.circle_outlined, label: 'Circle', isActive: tool == Tool.circle, onTap: () => cubit.setTool(Tool.circle)),
            _ToolButton(icon: Icons.change_history, label: 'Triangle', isActive: tool == Tool.triangle, onTap: () => cubit.setTool(Tool.triangle)),
            _ToolButton(icon: Icons.diamond_outlined, label: 'Diamond', isActive: tool == Tool.diamond, onTap: () => cubit.setTool(Tool.diamond)),
            _ToolButton(icon: Icons.star_border, label: 'Star', isActive: tool == Tool.star, onTap: () => cubit.setTool(Tool.star)),
            _ToolButton(icon: Icons.arrow_forward, label: 'Arrow', isActive: tool == Tool.arrow, onTap: () => cubit.setTool(Tool.arrow)),
          ]),
          const _VDiv(),
          _ToolGroup(label: 'Arrange', children: [
            _ToolButton(icon: Icons.flip_to_front, label: 'Bring Front', onTap: selId != null ? () => cubit.bringToFront(selId) : null),
            _ToolButton(icon: Icons.flip_to_back, label: 'Send Back', onTap: selId != null ? () => cubit.sendToBack(selId) : null),
            _ToolButton(icon: Icons.lock_outline, label: 'Lock', onTap: selId != null ? () => cubit.toggleElementLock(selId) : null),
            _ToolButton(icon: Icons.delete, label: 'Delete', onTap: selId != null ? cubit.deleteSelected : null),
          ]),
        ],
      ),
    );
  }
}

// ── Insert Tab ─────────────────────────────────────────────────────────────────

class _InsertToolbar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToolGroup(label: 'Text', children: [
            _ToolButton(icon: Icons.text_fields, label: 'Text Box', onTap: cubit.insertTextBox),
          ]),
          const _VDiv(),
          _ToolGroup(label: 'Images', children: [
            _ToolButton(
              icon: Icons.image_outlined,
              label: 'Picture',
              onTap: () async {
                final result = await FilePicker.pickFiles(
                  type: FileType.image,
                  allowMultiple: false,
                );
                if (result != null && context.mounted) {
                  final path = result.files.single.path;
                  if (path != null) cubit.insertImage(path);
                }
              },
            ),
          ]),
          const _VDiv(),
          _ToolGroup(label: 'Shapes', children: [
            _ToolButton(icon: Icons.rectangle_outlined, label: 'Rect', onTap: () => cubit.setTool(Tool.rectangle)),
            _ToolButton(icon: Icons.rounded_corner, label: 'Rounded', onTap: () => cubit.setTool(Tool.roundedRectangle)),
            _ToolButton(icon: Icons.circle_outlined, label: 'Circle', onTap: () => cubit.setTool(Tool.circle)),
            _ToolButton(icon: Icons.change_history, label: 'Triangle', onTap: () => cubit.setTool(Tool.triangle)),
            _ToolButton(icon: Icons.diamond_outlined, label: 'Diamond', onTap: () => cubit.setTool(Tool.diamond)),
            _ToolButton(icon: Icons.star_border, label: 'Star', onTap: () => cubit.setTool(Tool.star)),
            _ToolButton(icon: Icons.arrow_forward, label: 'Arrow', onTap: () => cubit.setTool(Tool.arrow)),
          ]),
          const _VDiv(),
          _ToolGroup(label: 'Table', children: [
            _ToolButton(
              icon: Icons.table_chart_outlined,
              label: 'Table',
              onTap: () => _showTableDialog(context, cubit),
            ),
          ]),
          const _VDiv(),
          _ToolGroup(label: 'Chart', children: [
            _ToolButton(icon: Icons.bar_chart, label: 'Column', onTap: () => cubit.insertChart(ChartType.column)),
            _ToolButton(icon: Icons.stacked_bar_chart, label: 'Bar', onTap: () => cubit.insertChart(ChartType.bar)),
            _ToolButton(icon: Icons.show_chart, label: 'Line', onTap: () => cubit.insertChart(ChartType.line)),
            _ToolButton(icon: Icons.pie_chart_outline, label: 'Pie', onTap: () => cubit.insertChart(ChartType.pie)),
          ]),
        ],
      ),
    );
  }

  Future<void> _showTableDialog(BuildContext context, EditorCubit cubit) async {
    int rows = 3;
    int cols = 4;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Insert Table'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Text('Rows: '),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: rows,
                  items: List.generate(10, (i) => i + 1)
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (v) => setSt(() => rows = v ?? rows),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Columns: '),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: cols,
                  items: List.generate(10, (i) => i + 1)
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (v) => setSt(() => cols = v ?? cols),
                ),
              ]),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                cubit.insertTable(rows, cols);
              },
              child: const Text('Insert'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Design Tab ─────────────────────────────────────────────────────────────────

class _DesignToolbar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    final slide = context.watch<EditorCubit>().state.activeSlide;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToolGroup(label: 'Background', children: [
            // Colour swatch button
            InkWell(
              onTap: () => _pickBackground(context, cubit, slide.backgroundColorOverride ?? const Color(0xFFFFFFFF)),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 52, height: 56,
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 28, height: 24,
                      decoration: BoxDecoration(
                        color: slide.backgroundColorOverride ?? Colors.white,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('Color', style: TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ),
            _ToolButton(
              icon: Icons.format_color_reset,
              label: 'Reset',
              onTap: () => cubit.updateSlideBackground(const Color(0xFFFFFFFF)),
            ),
          ]),
          const _VDiv(),
          _ToolGroup(label: 'Slide Size', children: [
            _ToolButton(icon: Icons.crop_16_9, label: 'Widescreen', onTap: () {}),
            _ToolButton(icon: Icons.crop_square, label: 'Standard', onTap: () {}),
          ]),
          const _VDiv(),
          _ToolGroup(label: 'Theme Colors', children: [
            for (final entry in _themePresets.entries)
              InkWell(
                onTap: () => cubit.updateSlideBackground(entry.value),
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 32, height: 56,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: entry.value,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(entry.key, style: const TextStyle(fontSize: 8), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  static const _themePresets = {
    'White': Color(0xFFFFFFFF),
    'Blue': Color(0xFFD6E4F7),
    'Dark': Color(0xFF1F2937),
    'Green': Color(0xFFD1FAE5),
    'Red': Color(0xFFFEE2E2),
    'Purple': Color(0xFFEDE9FE),
  };

  Future<void> _pickBackground(BuildContext context, EditorCubit cubit, Color current) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Background Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            onColorChanged: (c) => cubit.updateSlideBackground(c),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      ),
    );
  }
}

// ── Transitions Tab ────────────────────────────────────────────────────────────

class _TransitionsToolbar extends StatelessWidget {
  static const _transitions = [
    (TransitionType.none, Icons.block, 'None'),
    (TransitionType.fade, Icons.opacity, 'Fade'),
    (TransitionType.push, Icons.keyboard_arrow_right, 'Push'),
    (TransitionType.wipe, Icons.swipe_right_alt, 'Wipe'),
    (TransitionType.split, Icons.call_split, 'Split'),
    (TransitionType.reveal, Icons.zoom_in, 'Reveal'),
    (TransitionType.randomBars, Icons.view_column, 'Bars'),
    (TransitionType.cover, Icons.flip_to_back, 'Cover'),
    (TransitionType.uncover, Icons.flip_to_front, 'Uncover'),
    (TransitionType.clock, Icons.access_time, 'Clock'),
    (TransitionType.cube, Icons.view_in_ar, 'Cube'),
    (TransitionType.flip, Icons.flip, 'Flip'),
    (TransitionType.ripple, Icons.waves, 'Ripple'),
  ];

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    final slide = context.watch<EditorCubit>().state.activeSlide;
    final current = slide.transition.type;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToolGroup(
            label: 'Transition to This Slide',
            children: _transitions.map((t) {
              return _ToolButton(
                icon: t.$2,
                label: t.$3,
                isActive: current == t.$1,
                onTap: () => cubit.setSlideTransition(slide.transition.copyWith(type: t.$1)),
              );
            }).toList(),
          ),
          const _VDiv(),
          _ToolGroup(label: 'Timing', children: [
            _DurationPicker(
              value: slide.transition.duration,
              onChanged: (d) => cubit.setSlideTransition(slide.transition.copyWith(duration: d)),
            ),
          ]),
          const _VDiv(),
          _ToolGroup(label: 'Apply To', children: [
            _ToolButton(
              icon: Icons.done_all,
              label: 'All Slides',
              onTap: () {
                final t = slide.transition;
                final pres = cubit.state.presentation;
                for (int i = 0; i < pres.slides.length; i++) {
                  cubit.setSlideTransition(t);
                }
              },
            ),
          ]),
        ],
      ),
    );
  }
}

class _DurationPicker extends StatelessWidget {
  final Duration value;
  final ValueChanged<Duration> onChanged;
  const _DurationPicker({required this.value, required this.onChanged});

  static const _durations = [
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Duration', style: TextStyle(fontSize: 11)),
        const SizedBox(height: 4),
        DropdownButton<Duration>(
          value: _durations.contains(value) ? value : _durations[1],
          isDense: true,
          items: _durations
              .map((d) => DropdownMenuItem(
                    value: d,
                    child: Text('${d.inMilliseconds / 1000}s'),
                  ))
              .toList(),
          onChanged: (d) => d != null ? onChanged(d) : null,
        ),
      ],
    );
  }
}

// ── Animations Tab ─────────────────────────────────────────────────────────────

class _AnimationsToolbar extends StatelessWidget {
  static const _entrances = [
    (AnimationType.appear, Icons.visibility, 'Appear'),
    (AnimationType.fade, Icons.opacity, 'Fade In'),
    (AnimationType.fly, Icons.flight_land, 'Fly In'),
    (AnimationType.growShrink, Icons.zoom_in, 'Grow'),
    (AnimationType.spin, Icons.rotate_right, 'Spin'),
    (AnimationType.wipe, Icons.swipe_right, 'Wipe'),
  ];

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    final selId = state.selectedElementId;
    final slide = state.activeSlide;
    final anims = selId != null
        ? slide.animations.animations.where((a) => a.targetElementId == selId).toList()
        : <SlideAnimation>[];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToolGroup(
            label: 'Entrance',
            children: _entrances.map((e) {
              return _ToolButton(
                icon: e.$2,
                label: e.$3,
                isActive: anims.any((a) => a.type == e.$1 && a.category == AnimationCategory.entrance),
                onTap: selId != null
                    ? () {
                        final newAnim = SlideAnimation(
                          id: '${selId}_${e.$1.name}',
                          targetElementId: selId,
                          type: e.$1,
                          category: AnimationCategory.entrance,
                        );
                        final existing = List<SlideAnimation>.from(slide.animations.animations)..add(newAnim);
                        final s = slide.copyWith(
                          animations: AnimationTimeline(animations: existing),
                        );
                        final slides = List.from(state.presentation.slides);
                        slides[state.presentation.activeSlideIndex] = s;
                        cubit.updateElement(state.activeSlide.elements.firstWhere((el) => el.id == selId));
                      }
                    : null,
              );
            }).toList(),
          ),
          const _VDiv(),
          _ToolGroup(label: 'Current Animations', children: [
            if (anims.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: Text('None', style: TextStyle(color: Colors.grey, fontSize: 11)),
              ),
            for (final anim in anims)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${anim.type.name} (${anim.category.name})', style: const TextStyle(fontSize: 11)),
              ),
          ]),
        ],
      ),
    );
  }
}

// ── Slide Show Tab ─────────────────────────────────────────────────────────────

class _SlideShowToolbar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToolGroup(label: 'Start Slide Show', children: [
            _ToolButton(
              icon: Icons.slideshow,
              label: 'From Beginning',
              onTap: () {
                cubit.selectSlide(0);
                cubit.startPresentation();
              },
            ),
            _ToolButton(
              icon: Icons.play_circle_outline,
              label: 'From Current',
              onTap: cubit.startPresentation,
            ),
            _ToolButton(
              icon: Icons.present_to_all,
              label: 'Presenter View',
              onTap: () => cubit.startPresentation(presenterView: true),
            ),
          ]),
          const _VDiv(),
          _ToolGroup(label: 'Settings', children: [
            _ToolButton(icon: Icons.settings_outlined, label: 'Setup Show', onTap: () {}),
          ]),
        ],
      ),
    );
  }
}

// ── View Tab ───────────────────────────────────────────────────────────────────

class _ViewToolbar extends StatelessWidget {
  static const _zooms = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToolGroup(label: 'Zoom', children: [
            for (final z in _zooms)
              _ToolButton(
                icon: z < 1 ? Icons.zoom_out : z > 1 ? Icons.zoom_in : Icons.zoom_out_map,
                label: '${(z * 100).toInt()}%',
                isActive: (state.canvasZoom - z).abs() < 0.01,
                onTap: () => cubit.setZoom(z),
              ),
          ]),
          const _VDiv(),
          _ToolGroup(label: 'Window', children: [
            _ToolButton(icon: Icons.view_sidebar_outlined, label: 'Thumbnails', onTap: () {}),
            _ToolButton(icon: Icons.notes, label: 'Notes', onTap: () {}),
          ]),
        ],
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _Tab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _Tab({required this.label, this.isActive = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        height: 34,
        decoration: isActive
            ? const BoxDecoration(
                color: Color(0xFFF3F2F1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ToolGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _ToolGroup({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(spacing: 1, runSpacing: 2, children: children),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: label,
      child: Material(
        color: isActive ? Colors.grey[300] : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Opacity(
            opacity: enabled ? 1.0 : 0.4,
            child: Container(
              width: 50,
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isActive ? const Color(0xFFB7472A) : Colors.black87,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 9),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VDiv extends StatelessWidget {
  const _VDiv();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 80,
      child: VerticalDivider(width: 8, indent: 4, endIndent: 4),
    );
  }
}
