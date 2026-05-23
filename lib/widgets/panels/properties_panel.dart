import 'package:flutter/material.dart' hide SlideTransition;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_color_picker_plus/flutter_color_picker_plus.dart';
import '../../cubit/editor_cubit.dart';
import '../../models/elements.dart';
import '../../models/text_styles.dart';
import '../../models/animation.dart';

class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorCubit>().state;
    final selectedId = state.selectedElementId;

    if (selectedId == null) {
      return _SlideProperties();
    }

    final element = state.activeSlide.elements.firstWhere(
      (e) => e.id == selectedId,
      orElse: () => throw Exception('Element not found'),
    );

    return Material(
      color: Colors.grey[50],
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _SectionHeader(title: element.name ?? element.runtimeType.toString()),
          const Divider(),
          if (element is TextElement) _TextProperties(element: element),
          if (element is ShapeElement) _ShapeProperties(element: element),
          if (element is ImageElement) _ImageProperties(element: element),
          const Divider(),
          _PositionSizeProperties(element: element),
          const Divider(),
          _AnimationProperties(elementId: element.id),
        ],
      ),
    );
  }
}

class _SlideProperties extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    final slide = state.activeSlide;

    return Material(
      color: Colors.grey[50],
      child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Slide Properties'),
          const Divider(),
          ListTile(
            title: const Text('Background Color'),
            trailing: CircleAvatar(
              backgroundColor: slide.backgroundColorOverride ?? Colors.white,
              radius: 14,
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Pick color'),
                  content: SingleChildScrollView(
                    child: ColorPicker(
                      pickerColor:
                          slide.backgroundColorOverride ?? Colors.white,
                      onColorChanged: (color) =>
                          cubit.updateSlideBackground(color),
                    ),
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Done'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          const Text(
            'Transition',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<TransitionType>(
            value: slide.transition.type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: TransitionType.values.map((t) {
              return DropdownMenuItem(value: t, child: Text(t.name));
            }).toList(),
            onChanged: (type) {
              if (type != null) {
                cubit.setSlideTransition(SlideTransition(type: type));
              }
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<Duration>(
            value: slide.transition.duration,
            decoration: const InputDecoration(labelText: 'Duration'),
            items:
                [
                  const Duration(milliseconds: 500),
                  const Duration(milliseconds: 1000),
                  const Duration(milliseconds: 2000),
                  const Duration(milliseconds: 3000),
                ].map((d) {
                  return DropdownMenuItem(
                    value: d,
                    child: Text('${d.inSeconds}s'),
                  );
                }).toList(),
            onChanged: (dur) {
              if (dur != null) {
                cubit.setSlideTransition(
                  slide.transition.copyWith(duration: dur),
                );
              }
            },
          ),
        ],
      ),
      ),
    );
  }
}

class _TextProperties extends StatelessWidget {
  final TextElement element;
  const _TextProperties({required this.element});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Text Content',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(
            text: element.paragraphs.map((p) => p.plainText).join('\n'),
          ),
          maxLines: 5,
          onChanged: (val) {
            final paragraphs = val
                .split('\n')
                .map((line) => RichParagraph(runs: [TextRun(text: line)]))
                .toList();
            cubit.updateTextElement(element.id, paragraphs);
          },
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          title: const Text('Wrap text'),
          value: element.wrapText,
          onChanged: (v) => cubit.updateElement(element.copyWith(wrapText: v)),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        CheckboxListTile(
          title: const Text('Auto-fit'),
          value: element.autoFit,
          onChanged: (v) => cubit.updateElement(element.copyWith(autoFit: v)),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }
}

class _ShapeProperties extends StatelessWidget {
  final ShapeElement element;
  const _ShapeProperties({required this.element});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: const Text('Fill Color'),
          trailing: CircleAvatar(
            backgroundColor: element.fillColor,
            radius: 14,
          ),
          onTap: () => _pickColor(
            context,
            element.fillColor,
            (c) => cubit.updateElement(element.copyWith(fillColor: c)),
          ),
        ),
        ListTile(
          title: const Text('Stroke Color'),
          trailing: CircleAvatar(
            backgroundColor: element.strokeColor,
            radius: 14,
          ),
          onTap: () => _pickColor(
            context,
            element.strokeColor,
            (c) => cubit.updateElement(element.copyWith(strokeColor: c)),
          ),
        ),
        ListTile(
          title: const Text('Stroke Width'),
          subtitle: Text('${element.strokeWidth.toStringAsFixed(1)} pt'),
        ),
        Slider(
          value: element.strokeWidth,
          min: 0,
          max: 20,
          onChanged: (v) =>
              cubit.updateElement(element.copyWith(strokeWidth: v)),
        ),
        DropdownButtonFormField<ShapeType>(
          value: element.shapeType,
          decoration: const InputDecoration(labelText: 'Shape Type'),
          items: ShapeType.values
              .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
              .toList(),
          onChanged: (v) {
            if (v != null) cubit.updateElement(element.copyWith(shapeType: v));
          },
        ),
      ],
    );
  }

  void _pickColor(
    BuildContext context,
    Color current,
    Function(Color) onColorChanged,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pick color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            onColorChanged: onColorChanged,
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Done'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _ImageProperties extends StatelessWidget {
  final ImageElement element;
  const _ImageProperties({required this.element});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<ImageFillMode>(
          value: element.fillMode,
          decoration: const InputDecoration(labelText: 'Fill Mode'),
          items: ImageFillMode.values
              .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
              .toList(),
          onChanged: (v) {
            if (v != null) cubit.updateElement(element.copyWith(fillMode: v));
          },
        ),
        const SizedBox(height: 12),
        const Text('Brightness'),
        Slider(
          value: element.brightness,
          min: -1,
          max: 1,
          onChanged: (v) =>
              cubit.updateElement(element.copyWith(brightness: v)),
        ),
        const Text('Contrast'),
        Slider(
          value: element.contrast,
          min: -1,
          max: 1,
          onChanged: (v) => cubit.updateElement(element.copyWith(contrast: v)),
        ),
      ],
    );
  }
}

class _PositionSizeProperties extends StatelessWidget {
  final SlideElement element;
  const _PositionSizeProperties({required this.element});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Position & Size',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: 'X'),
                controller: TextEditingController(
                  text: element.position.dx.toStringAsFixed(1),
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (v) {
                  final val = double.tryParse(v);
                  if (val != null) {
                    cubit.updateElement(
                      element.copyWith(
                        position: Offset(val, element.position.dy),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: 'Y'),
                controller: TextEditingController(
                  text: element.position.dy.toStringAsFixed(1),
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (v) {
                  final val = double.tryParse(v);
                  if (val != null) {
                    cubit.updateElement(
                      element.copyWith(
                        position: Offset(element.position.dx, val),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: 'Width'),
                controller: TextEditingController(
                  text: element.size.width.toStringAsFixed(1),
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (v) {
                  final val = double.tryParse(v);
                  if (val != null) {
                    cubit.updateElement(
                      element.copyWith(size: Size(val, element.size.height)),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: 'Height'),
                controller: TextEditingController(
                  text: element.size.height.toStringAsFixed(1),
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (v) {
                  final val = double.tryParse(v);
                  if (val != null) {
                    cubit.updateElement(
                      element.copyWith(size: Size(element.size.width, val)),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: 'Rotation'),
                controller: TextEditingController(
                  text: element.rotation.toStringAsFixed(1),
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (v) {
                  final val = double.tryParse(v);
                  if (val != null) {
                    cubit.updateElement(element.copyWith(rotation: val));
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnimationProperties extends StatelessWidget {
  final String elementId;
  const _AnimationProperties({required this.elementId});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    final slide = state.activeSlide;
    final animations = slide.animations.animations
        .where((a) => a.targetElementId == elementId)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Animations', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (animations.isEmpty)
          const Text('No animations', style: TextStyle(color: Colors.grey)),
        ...animations.map(
          (anim) => ListTile(
            dense: true,
            title: Text(anim.type.name),
            subtitle: Text(anim.category.name),
            trailing: IconButton(
              icon: const Icon(Icons.delete, size: 18),
              onPressed: () {
                cubit.removeAnimationFromElement(elementId, anim.id);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (dialogCtx) {
                AnimationType selectedType = AnimationType.fade;
                AnimationCategory selectedCategory = AnimationCategory.entrance;

                return StatefulBuilder(
                  builder: (ctx, setSt) => AlertDialog(
                    title: const Text('Add Animation'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<AnimationCategory>(
                          value: selectedCategory,
                          decoration: const InputDecoration(labelText: 'Category'),
                          items: AnimationCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                          onChanged: (cat) {
                            if (cat != null) {
                              setSt(() => selectedCategory = cat);
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<AnimationType>(
                          value: selectedType,
                          decoration: const InputDecoration(labelText: 'Effect Type'),
                          items: AnimationType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                          onChanged: (type) {
                            if (type != null) {
                              setSt(() => selectedType = type);
                            }
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () {
                          cubit.addAnimationToElement(elementId, selectedType, selectedCategory);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Animation'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    );
  }
}
