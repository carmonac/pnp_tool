import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pnp_core/pnp_core.dart';

import '../state/project_controller.dart';
import '../state/recent_projects.dart';
import '../strings.dart';
import 'editor_screen.dart';
import 'new_project_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _recents = RecentProjects();
  List<String> _recentPaths = [];

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final paths = await _recents.load();
    if (mounted) setState(() => _recentPaths = paths);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(32),
            children: [
              Text(
                Strings.appTitle,
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _BigButton(
                icon: Icons.grid_view,
                title: Strings.newGridProject,
                subtitle: Strings.newGridProjectSubtitle,
                onTap: () => _newProject(ProjectMode.grid),
              ),
              const SizedBox(height: 12),
              _BigButton(
                icon: Icons.dashboard_customize_outlined,
                title: Strings.newFreeformProject,
                subtitle: Strings.newFreeformProjectSubtitle,
                onTap: () => _newProject(ProjectMode.freeform),
              ),
              const SizedBox(height: 12),
              _BigButton(
                icon: Icons.folder_open_outlined,
                title: Strings.openProject,
                subtitle: '.pnp.json',
                onTap: _openProject,
              ),
              if (_recentPaths.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text(Strings.recentProjects,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final path in _recentPaths)
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(p.basename(path)),
                    subtitle: Text(
                      p.dirname(path),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _openPath(path),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _newProject(ProjectMode mode) async {
    final config = await showNewProjectDialog(context, mode: mode);
    if (config == null || !mounted) return;

    final project = PnpProject(
      name: config.name,
      mode: mode,
      pageSize: config.pageSize,
      cardSize: config.cardSize ?? const SizeMm(63.5, 88.9),
    );
    await _openEditor(ProjectController(project));
  }

  Future<void> _openProject() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Proyecto PnP', extensions: ['json']),
      ],
    );
    if (file != null) await _openPath(file.path);
  }

  Future<void> _openPath(String path) async {
    try {
      final controller = ProjectController.load(path);
      await _recents.add(path);
      await _openEditor(controller);
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${Strings.error}: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
      // Drop entries whose file vanished or no longer parses.
      if (e is PathNotFoundException) await _loadRecents();
    }
  }

  Future<void> _openEditor(ProjectController controller) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => EditorScreen(controller: controller),
    ));
    controller.dispose();
    await _loadRecents();
  }
}

class _BigButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BigButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Icon(icon, size: 36),
        title: Text(title,
            style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}
