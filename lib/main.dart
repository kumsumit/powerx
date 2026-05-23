import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'cubit/editor_cubit.dart';
import 'widgets/editor_shell.dart';

void main() {
  runApp(const PowerPointApp());
}

class PowerPointApp extends StatelessWidget {
  const PowerPointApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter PowerPoint',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB7472A)), // PowerPoint red
      ),
      home: BlocProvider(
        create: (_) => EditorCubit(),
        child: const EditorShell(),
      ),
    );
  }
}