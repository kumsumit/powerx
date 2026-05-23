import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorShortcuts extends StatelessWidget {
  final Widget child;
  final Map<ShortcutActivator, VoidCallback> shortcuts;

  const EditorShortcuts({
    super.key,
    required this.child,
    required this.shortcuts,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        for (final entry in shortcuts.entries)
          entry.key: VoidCallbackIntent(entry.value),
      },
      child: Actions(
        actions: {
          VoidCallbackIntent: CallbackAction<VoidCallbackIntent>(
            onInvoke: (intent) => intent.callback(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

class VoidCallbackIntent extends Intent {
  final VoidCallback callback;
  const VoidCallbackIntent(this.callback);
}

class EditorShortcutActivators {
  static const ctrlN = SingleActivator(LogicalKeyboardKey.keyN, control: true);
  static const ctrlO = SingleActivator(LogicalKeyboardKey.keyO, control: true);
  static const ctrlS = SingleActivator(LogicalKeyboardKey.keyS, control: true);
  static const ctrlZ = SingleActivator(LogicalKeyboardKey.keyZ, control: true);
  static const ctrlY = SingleActivator(LogicalKeyboardKey.keyY, control: true);
  static const ctrlShiftZ = SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true);
  static const delete = SingleActivator(LogicalKeyboardKey.delete);
  static const ctrlD = SingleActivator(LogicalKeyboardKey.keyD, control: true);
  static const ctrlG = SingleActivator(LogicalKeyboardKey.keyG, control: true);
  static const ctrlShiftG = SingleActivator(LogicalKeyboardKey.keyG, control: true, shift: true);
  static const ctrlB = SingleActivator(LogicalKeyboardKey.keyB, control: true);
  static const ctrlI = SingleActivator(LogicalKeyboardKey.keyI, control: true);
  static const ctrlU = SingleActivator(LogicalKeyboardKey.keyU, control: true);
  static const f5 = SingleActivator(LogicalKeyboardKey.f5);
  static const shiftF5 = SingleActivator(LogicalKeyboardKey.f5, shift: true);
  static const escape = SingleActivator(LogicalKeyboardKey.escape);
  static const ctrlC = SingleActivator(LogicalKeyboardKey.keyC, control: true);
  static const ctrlV = SingleActivator(LogicalKeyboardKey.keyV, control: true);
  static const ctrlX = SingleActivator(LogicalKeyboardKey.keyX, control: true);
}
