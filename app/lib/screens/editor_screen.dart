import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pnp_core/pnp_core.dart';
import 'package:provider/provider.dart';

import '../state/project_controller.dart';
import '../state/recent_projects.dart';
import '../strings.dart';
import '../widgets/card_detail_dialog.dart';
import '../widgets/card_list_sidebar.dart';
import '../widgets/export_dialog.dart';
import '../widgets/freeform_canvas.dart';
import '../widgets/freeform_sidebar.dart';
import '../widgets/page_preview.dart';
import '../widgets/page_thumbnail_strip.dart';
import '../widgets/settings_dialog.dart';

const _imageExtensions = {'.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'};

class EditorScreen extends StatelessWidget {
  final ProjectController controller;

  const EditorScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: controller),
        ChangeNotifierProvider(create: (_) => PreviewImageCache()),
      ],
      child: const _EditorScaffold(),
    );
  }
}

class _EditorScaffold extends StatelessWidget {
  const _EditorScaffold();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final isGrid = controller.project.mode == ProjectMode.grid;

    return PopScope(
      canPop: !controller.dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final leave = await _confirmDiscard(context, controller);
        if (leave && navigator.mounted) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              '${controller.project.name}${controller.dirty ? ' •' : ''}'),
          actions: [
            IconButton(
              tooltip: Strings.undo,
              icon: const Icon(Icons.undo),
              onPressed: controller.canUndo ? controller.undo : null,
            ),
            IconButton(
              tooltip: Strings.redo,
              icon: const Icon(Icons.redo),
              onPressed: controller.canRedo ? controller.redo : null,
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: Strings.settings,
              icon: const Icon(Icons.tune),
              onPressed: () => showProjectSettings(context, controller),
            ),
            IconButton(
              tooltip: Strings.save,
              icon: const Icon(Icons.save_outlined),
              onPressed: () => _save(context, controller),
            ),
            IconButton(
              tooltip: Strings.shareBundle,
              icon: const Icon(Icons.ios_share),
              onPressed: () => _shareBundle(context, controller),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text(Strings.exportPdf),
              onPressed: controller.plans.isEmpty
                  ? null
                  : () => exportPdfFlow(context, controller),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Row(
          children: [
            if (isGrid) const CardListSidebar() else const FreeformSidebar(),
            const VerticalDivider(width: 1),
            Expanded(
              child: DropTarget(
                onDragDone: (details) => _onDrop(controller, details),
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: isGrid
                      ? const _GridMainView()
                      : const FreeformCanvas(),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            const PageThumbnailStrip(),
          ],
        ),
      ),
    );
  }

  void _onDrop(ProjectController controller, DropDoneDetails details) {
    final paths = details.files
        .map((f) => f.path)
        .where((path) =>
            _imageExtensions.contains(p.extension(path).toLowerCase()))
        .toList();
    if (paths.isEmpty) return;

    if (controller.project.mode == ProjectMode.grid) {
      controller.addCards(paths);
    } else {
      for (final path in paths) {
        controller.addFreeItem(controller.selectedSheetIndex, path);
      }
    }
  }

  Future<void> _save(
      BuildContext context, ProjectController controller) async {
    if (!controller.hasSaveTarget) {
      final location = await getSaveLocation(
        suggestedName: '${controller.project.name}.pnp.json',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Proyecto PnP', extensions: ['json']),
        ],
      );
      if (location == null) return;
      await controller.saveAs(location.path);
    } else {
      await controller.save();
    }
    final path = controller.filePath ?? controller.bundlePath;
    if (path != null) await RecentProjects().add(path);
  }

  /// Exports a self-contained .pnp bundle (project + images) for sharing.
  Future<void> _shareBundle(
      BuildContext context, ProjectController controller) async {
    final location = await getSaveLocation(
      suggestedName: '${controller.project.name}.pnp',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Proyecto PnP empaquetado', extensions: ['pnp']),
      ],
    );
    if (location == null) return;
    try {
      await controller.exportBundle(location.path);
      await RecentProjects().add(location.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${Strings.bundleExported}: ${location.path}'),
        ));
      }
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${Strings.error}: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  Future<bool> _confirmDiscard(
      BuildContext context, ProjectController controller) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Strings.unsavedChanges),
        content: const Text(Strings.unsavedChangesBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text(Strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text(Strings.discard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text(Strings.save),
          ),
        ],
      ),
    );
    if (result == 'save') {
      if (!context.mounted) return false;
      await _save(context, controller);
      return !controller.dirty;
    }
    return result == 'discard';
  }
}

/// Grid mode center view: large preview of the selected page.
class _GridMainView extends StatelessWidget {
  const _GridMainView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final plan = controller.selectedPlan;

    if (plan == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(Strings.emptyProjectHint, textAlign: TextAlign.center),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
              ),
            ],
          ),
          child: PagePreview(
            plan: plan,
            fitMode: controller.project.fitMode,
            imageCache: context.read<PreviewImageCache>(),
            // Clicking a card on the page opens its detail modal.
            onImageTap: (sourceId) {
              if (sourceId != null) {
                showCardDetailDialog(context, controller, sourceId);
              }
            },
          ),
        ),
      ),
    );
  }
}
