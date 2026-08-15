import 'dart:io';

import 'package:flutter/material.dart';

import 'screens/editor_screen.dart';
import 'screens/home_screen.dart';
import 'state/project_controller.dart';
import 'strings.dart';

void main(List<String> args) {
  // Optional: open a .pnp.json project passed on the command line.
  ProjectController? initial;
  final path = args.where((a) => a.endsWith('.json')).firstOrNull;
  if (path != null && File(path).existsSync()) {
    try {
      initial = ProjectController.load(path);
    } catch (_) {}
  }
  runApp(PnpStudioApp(initialController: initial));
}

class PnpStudioApp extends StatelessWidget {
  final ProjectController? initialController;

  const PnpStudioApp({super.key, this.initialController});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Strings.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: initialController == null
          ? const HomeScreen()
          : EditorScreen(controller: initialController!),
    );
  }
}
