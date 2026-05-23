import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/editor_cubit.dart';

class Ribbon extends StatelessWidget {
  const Ribbon({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    final tool = context.select((EditorCubit c) => c.state.activeTool);

    return Container(
      height: 110,
      color: const Color(0xFFB7472A), // PowerPoint brand color
      child: Column(
        children: [
          // Tabs
          Container(
            height: 32,
            color: const Color(0xFFB7472A),
            child: Row(
              children: [
                _Tab(label: 'File', onTap: () {}),
                _Tab(label: 'Home', isActive: true, onTap: () {}),
                _Tab(label: 'Insert', onTap: () {}),
                _Tab(label: 'Design', onTap: () {}),
                _Tab(label: 'Transitions', onTap: () {}),
                _Tab(label: 'Animations', onTap: () {}),
                _Tab(label: 'Slide Show', onTap: cubit.startPresentation),
              ],
            ),
          ),
          // Toolbar
          Container(
            height: 78,
            color: const Color(0xFFF3F2F1),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _ToolGroup(
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
                  ],
                ),
                const VerticalDivider(),
                _ToolGroup(
                  children: [
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
                  ],
                ),
                const VerticalDivider(),
                _ToolGroup(
                  children: [
                    _ToolButton(
                      icon: Icons.delete,
                      label: 'Delete',
                      onTap: cubit.deleteSelected,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: isActive
            ? const BoxDecoration(
                color: Color(0xFFF3F2F1),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ToolGroup extends StatelessWidget {
  final List<Widget> children;
  const _ToolGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(children: children),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _ToolButton({required this.icon, required this.label, this.isActive = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 64,
        decoration: isActive ? BoxDecoration(color: Colors.grey[300]) : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isActive ? const Color(0xFFB7472A) : Colors.black87),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}