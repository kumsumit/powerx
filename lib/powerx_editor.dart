import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cubit/editor_cubit.dart';
import 'widgets/editor_shell.dart';

class PowerXEditor extends StatelessWidget {
  const PowerXEditor({super.key, this.editorCubit});

  final EditorCubit? editorCubit;

  @override
  Widget build(BuildContext context) {
    final cubit = editorCubit;
    if (cubit != null) {
      return BlocProvider.value(value: cubit, child: const EditorShell());
    }

    return BlocProvider(
      create: (_) => EditorCubit(),
      child: const EditorShell(),
    );
  }
}
