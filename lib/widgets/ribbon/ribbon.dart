import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubit/editor_cubit.dart';

class Ribbon extends StatelessWidget {
  const Ribbon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      color: const Color(0xFFB7472A),
      child: Column(
        children: [
          _RibbonTabs(),
          Expanded(
            child: Container(
              color: const Color(0xFFF3F2F1),
              child: _RibbonToolbar(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RibbonTabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      color: const Color(0xFFB7472A),
      child: Row(
        children: [
          _Tab(label: 'File', onTap: () => _showFileMenu(context)),
          _Tab(label: 'Home', isActive: true, onTap: () {}),
          _Tab(label: 'Insert', onTap: () {}),
          _Tab(label: 'Design', onTap: () {}),
          _Tab(label: 'Transitions', onTap: () {}),
          _Tab(label: 'Animations', onTap: () {}),
          _Tab(
            label: 'Slide Show',
            onTap: () => context.read<EditorCubit>().startPresentation(),
          ),
          _Tab(label: 'Review', onTap: () {}),
          _Tab(label: 'View', onTap: () {}),
        ],
      ),
    );
  }

  void _showFileMenu(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('New'),
              onTap: () {
                cubit.newPresentation();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Open'),
              onTap: () async {
                // Use file_picker in real implementation
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save),
              title: const Text('Save'),
              onTap: () async {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
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

class _RibbonToolbar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    final tool = context.select((EditorCubit c) => c.state.activeTool);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToolGroup(
            label: 'Clipboard',
            children: [
              _ToolButton(icon: Icons.paste, label: 'Paste', onTap: () {}),
              _ToolButton(icon: Icons.undo, label: 'Undo', onTap: cubit.undo),
            ],
          ),
          const VerticalDivider(width: 1, indent: 4, endIndent: 4),
          _ToolGroup(
            label: 'Slides',
            children: [
              _ToolButton(
                icon: Icons.add_box,
                label: 'New Slide',
                onTap: cubit.addSlide,
              ),
              _ToolButton(
                icon: Icons.content_copy,
                label: 'Duplicate',
                onTap: () => cubit.duplicateSlide(
                  cubit.state.presentation.activeSlideIndex,
                ),
              ),
            ],
          ),
          const VerticalDivider(width: 1, indent: 4, endIndent: 4),
          _ToolGroup(
            label: 'Drawing',
            children: [
              _ToolButton(
                icon: Icons.pan_tool,
                label: 'Select',
                isActive: tool == Tool.select,
                onTap: () => cubit.setTool(Tool.select),
              ),
              _ToolButton(
                icon: Icons.text_fields,
                label: 'Text Box',
                isActive: tool == Tool.textBox,
                onTap: () => cubit.setTool(Tool.textBox),
              ),
              _ToolButton(
                icon: Icons.rectangle_outlined,
                label: 'Rectangle',
                isActive: tool == Tool.rectangle,
                onTap: () => cubit.setTool(Tool.rectangle),
              ),
              _ToolButton(
                icon: Icons.circle_outlined,
                label: 'Circle',
                isActive: tool == Tool.circle,
                onTap: () => cubit.setTool(Tool.circle),
              ),
              _ToolButton(
                icon: Icons.change_history,
                label: 'Triangle',
                isActive: tool == Tool.triangle,
                onTap: () => cubit.setTool(Tool.triangle),
              ),
              _ToolButton(
                icon: Icons.star_border,
                label: 'Star',
                isActive: tool == Tool.star,
                onTap: () => cubit.setTool(Tool.star),
              ),
              _ToolButton(
                icon: Icons.arrow_forward,
                label: 'Arrow',
                isActive: tool == Tool.arrow,
                onTap: () => cubit.setTool(Tool.arrow),
              ),
            ],
          ),
          const VerticalDivider(width: 1, indent: 4, endIndent: 4),
          _ToolGroup(
            label: 'Arrange',
            children: [
              _ToolButton(
                icon: Icons.flip_to_front,
                label: 'Bring Forward',
                onTap: () {
                  final id = cubit.state.selectedElementId;
                  if (id != null) cubit.bringToFront(id);
                },
              ),
              _ToolButton(
                icon: Icons.flip_to_back,
                label: 'Send Backward',
                onTap: () {
                  final id = cubit.state.selectedElementId;
                  if (id != null) cubit.sendToBack(id);
                },
              ),
              _ToolButton(
                icon: Icons.delete,
                label: 'Delete',
                onTap: cubit.deleteSelected,
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(spacing: 2, runSpacing: 2, children: children),
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
    return Material(
      color: isActive ? Colors.grey[300] : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 52,
          height: 56,
          padding: const EdgeInsets.all(2),
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
    );
  }
}
