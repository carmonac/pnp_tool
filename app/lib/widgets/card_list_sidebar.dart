import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/project_controller.dart';
import '../strings.dart';

const imageTypeGroup = XTypeGroup(
  label: 'Imágenes',
  extensions: ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'],
);

/// Grid-mode sidebar: card list with thumbnails, per-card back management,
/// copy counts, reorder, and global back controls.
class CardListSidebar extends StatelessWidget {
  const CardListSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final cards = controller.project.cards;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SizedBox(
        width: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${Strings.cards} (${cards.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: Strings.addCards,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    onPressed: () => _pickCards(controller),
                  ),
                  IconButton(
                    tooltip: Strings.importFolder,
                    icon: const Icon(Icons.drive_folder_upload_outlined),
                    onPressed: () => _importFolder(controller),
                  ),
                ],
              ),
            ),
            _GlobalBackTile(controller: controller),
            const Divider(height: 1),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: cards.length,
                onReorderItem: controller.reorderCards,
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return _CardTile(
                    key: ValueKey(card.id),
                    index: index,
                    cardId: card.id,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCards(ProjectController controller) async {
    final files = await openFiles(acceptedTypeGroups: [imageTypeGroup]);
    controller.addCards(files.map((f) => f.path).toList());
  }

  Future<void> _importFolder(ProjectController controller) async {
    final dir = await getDirectoryPath();
    if (dir != null) {
      await controller.importFolder(dir);
    }
  }
}

class _GlobalBackTile extends StatelessWidget {
  final ProjectController controller;

  const _GlobalBackTile({required this.controller});

  @override
  Widget build(BuildContext context) {
    final globalBack = controller.project.globalBackRef;
    return ListTile(
      dense: true,
      leading: globalBack == null
          ? const Icon(Icons.flip_to_back_outlined)
          : _thumbnail(globalBack),
      title: Text(Strings.globalBack),
      subtitle: globalBack == null
          ? null
          : Text(
              globalBack.split(Platform.pathSeparator).last,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: PopupMenuButton<String>(
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'set', child: Text(Strings.setGlobalBack)),
          if (globalBack != null)
            const PopupMenuItem(
              value: 'clear',
              child: Text(Strings.clearGlobalBack),
            ),
        ],
        onSelected: (value) async {
          if (value == 'set') {
            final file = await openFile(acceptedTypeGroups: [imageTypeGroup]);
            if (file != null) controller.setGlobalBack(file.path);
          } else {
            controller.setGlobalBack(null);
          }
        },
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final int index;
  final String cardId;

  const _CardTile({super.key, required this.index, required this.cardId});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final card = controller.project.cards.firstWhere((c) => c.id == cardId);
    final hasOwnBack = card.backRef != null;
    final hasAnyBack = hasOwnBack || controller.project.globalBackRef != null;

    return ReorderableDragStartListener(
      index: index,
      child: ListTile(
        dense: true,
        leading: _thumbnail(card.frontRef),
        title: Text(
          card.frontRef.split(Platform.pathSeparator).last,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Icon(
              hasAnyBack ? Icons.flip_to_back : Icons.report_outlined,
              size: 14,
              color: hasAnyBack
                  ? (hasOwnBack ? Colors.teal : Colors.grey)
                  : Colors.orange,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                hasOwnBack
                    ? Strings.back
                    : (hasAnyBack ? Strings.globalBack : '—'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            if (card.count > 1) Text('×${card.count}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'back', child: Text(Strings.setBack)),
            if (hasOwnBack)
              const PopupMenuItem(
                value: 'clearBack',
                child: Text(Strings.clearBack),
              ),
            const PopupMenuItem(value: 'count', child: Text(Strings.copies)),
            const PopupMenuItem(
              value: 'remove',
              child: Text(Strings.removeCard),
            ),
          ],
          onSelected: (value) => _onAction(context, controller, value),
        ),
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    ProjectController controller,
    String action,
  ) async {
    switch (action) {
      case 'back':
        final file = await openFile(acceptedTypeGroups: [imageTypeGroup]);
        if (file != null) controller.setCardBack(cardId, file.path);
      case 'clearBack':
        controller.setCardBack(cardId, null);
      case 'remove':
        controller.removeCard(cardId);
      case 'count':
        if (!context.mounted) return;
        final card = controller.project.cards.firstWhere((c) => c.id == cardId);
        final result = await showDialog<int>(
          context: context,
          builder: (context) => _CountDialog(initial: card.count),
        );
        if (result != null) controller.setCardCount(cardId, result);
    }
  }
}

class _CountDialog extends StatefulWidget {
  final int initial;

  const _CountDialog({required this.initial});

  @override
  State<_CountDialog> createState() => _CountDialogState();
}

class _CountDialogState extends State<_CountDialog> {
  late int count = widget.initial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(Strings.copies),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: count > 1 ? () => setState(() => count--) : null,
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => setState(() => count++),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(Strings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, count),
          child: const Text(Strings.accept),
        ),
      ],
    );
  }
}

Widget _thumbnail(String path) => ClipRRect(
  borderRadius: BorderRadius.circular(4),
  child: Image.file(
    File(path),
    width: 36,
    height: 50,
    fit: BoxFit.cover,
    cacheWidth: 72,
    errorBuilder: (context, error, stack) =>
        const Icon(Icons.broken_image_outlined),
  ),
);
