import 'dart:io';

import 'package:flutter/material.dart';

import 'screens/editor_screen.dart';
import 'screens/home_screen.dart';
import 'state/project_controller.dart';
import 'strings.dart';
import 'theme.dart';

Future<void> main(List<String> args) async {
  // Optional: open a project (.pnp.json or .pnp bundle) passed on the
  // command line.
  ProjectController? initial;
  final path = args
      .where((a) => a.endsWith('.json') || a.toLowerCase().endsWith('.pnp'))
      .firstOrNull;
  if (path != null && File(path).existsSync()) {
    try {
      if (path.toLowerCase().endsWith('.pnp')) {
        WidgetsFlutterBinding.ensureInitialized();
        initial = await ProjectController.loadBundle(path);
      } else {
        initial = ProjectController.load(path);
      }
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
      theme: desktopTheme(Brightness.light),
      darkTheme: desktopTheme(Brightness.dark),
      debugShowCheckedModeBanner: false,
      home: initialController == null
          ? const HomeScreen()
          : EditorScreen(controller: initialController!),
    );
  }
}
