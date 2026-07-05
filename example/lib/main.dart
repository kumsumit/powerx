import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:powerx/powerx.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const PowerXExampleApp());
}

class PowerXExampleApp extends StatelessWidget {
  const PowerXExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PowerX Example',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB7472A)),
        fontFamily: 'Calibri',
      ),
      home: const PowerXEditor(),
    );
  }
}
