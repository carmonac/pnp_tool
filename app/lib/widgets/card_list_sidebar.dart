import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pnp_core/pnp_core.dart';
import 'package:provider/provider.dart';

import '../state/project_controller.dart';
import '../strings.dart';
import 'card_detail_dialog.dart';
import 'image_drop_dialog.dart';

const imageTypeGroup = XTypeGroup(
  label: 'Imágenes',
  extensions: ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'],
);

/// Grid-mode sidebar: card list with thumbnails, multi-selection, per-card
/// back management, copy counts, reorder, and global back controls.
class CardListSidebar extends StatelessWidget {
  const CardListSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final cards = controller.project.cards;
    final selection = controller.selectedCardIds;

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
                    tooltip: Strings.selectMode,
                    isSelected: controller.selectionMode,
                    icon: const Icon(Icons.checklist),
                    onPressed: () =>
                        controller.setSelectionMode(!controller.selectionMode),
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
            _GlobalBacksSection(controller: controller),
            const Divider(height: 1),
            if (controller.selectionMode)
              _SelectionBar(controller: controller, selection: selection),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: cards.length,
                onReorderItem: controller.reorderCards,
                // The dragged proxy is mounted in the overlay, outside our
                // Material; give it one so ListTile can render there.
                proxyDecorator: (child, index, animation) =>
                    Material(elevation: 4, child: child),
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return _CardTile(
                    key: ValueKey(card.id),
                    index: index,
                    card: card,
                    controller: controller,
                    selected: selection.contains(card.id),
                    selectionMode: controller.selectionMode,
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

/// Bulk actions for the current card selection.
class _SelectionBar extends StatelessWidget {
  final ProjectController controller;
  final Set<String> selection;

  const _SelectionBar({required this.controller, required this.selection});

  @override
  Widget build(BuildContext context) {
    final backs = controller.project.globalBacks;
    return ColoredBox(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${selection.length} ${Strings.selectedCount}',
                style: Theme.of(context).textTheme.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: Strings.assignGlobalBack,
              icon: const Icon(Icons.flip_to_back, size: 18),
              itemBuilder: (context) => [
                for (final back in backs)
                  PopupMenuItem(
                    value: 'global:${back.id}',
                    child: Text(
                      '${Strings.useGlobalBack}: '
                      '${back.ref.split(Platform.pathSeparator).last}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'globalDefault',
                  child: Text(Strings.useDefaultBack),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'selectAll',
                  child: Text(Strings.selectAll),
                ),
                const PopupMenuItem(
                  value: 'removeSelected',
                  child: Text(Strings.removeSelected),
                ),
              ],
              onSelected: (value) {
                if (value.startsWith('global:')) {
                  controller.setCardsGlobalBack(
                      selection, value.substring('global:'.length));
                } else if (value == 'globalDefault') {
                  controller.setCardsGlobalBack(selection, null);
                } else if (value == 'selectAll') {
                  controller.selectAllCards();
                } else if (value == 'removeSelected') {
                  controller.removeCards(selection);
                }
              },
            ),
            IconButton(
              tooltip: Strings.clearSelection,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => controller.setSelectionMode(false),
            ),
          ],
        ),
      ),
    );
  }
}

/// The project's shared backs: the first one is the default for every card
/// without an explicit choice; cards can point to any of the others.
class _GlobalBacksSection extends StatelessWidget {
  final ProjectController controller;

  const _GlobalBacksSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final backs = controller.project.globalBacks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  Strings.globalBacks,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: Strings.addGlobalBack,
                icon: const Icon(Icons.flip_to_back_outlined),
                onPressed: () async {
                  final paths = await showImageDropDialog(context,
                      title: Strings.addGlobalBack);
                  if (paths == null) return;
                  for (final path in paths) {
                    controller.addGlobalBack(path);
                  }
                },
              ),
            ],
          ),
        ),
        for (final (index, back) in backs.indexed)
          ListTile(
            dense: true,
            leading: _thumbnail(back.ref),
            title: Text(
              back.ref.split(Platform.pathSeparator).last,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: index == 0 ? const Text(Strings.defaultBackSuffix) : null,
            trailing: IconButton(
              tooltip: Strings.removeGlobalBack,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => controller.removeGlobalBack(back.id),
            ),
          ),
      ],
    );
  }
}

/// One card row. Deliberately Provider-free: everything arrives via
/// constructor so the tile still builds inside the drag overlay, which sits
/// outside the editor's provider scope.
class _CardTile extends StatelessWidget {
  final int index;
  final CardItem card;
  final ProjectController controller;
  final bool selected;
  final bool selectionMode;

  const _CardTile({
    super.key,
    required this.index,
    required this.card,
    required this.controller,
    required this.selected,
    required this.selectionMode,
  });

  @override
  Widget build(BuildContext context) {
    final project = controller.project;
    final hasOwnBack = card.backRef != null;
    final appliedBack = project.backRefFor(card);

    final String backLabel;
    if (hasOwnBack) {
      backLabel = Strings.back;
    } else if (appliedBack != null) {
      backLabel = appliedBack.split(Platform.pathSeparator).last;
    } else {
      backLabel = '—';
    }

    return ReorderableDragStartListener(
      index: index,
      child: ListTile(
        dense: true,
        selected: selected,
        onTap: selectionMode
            ? () => controller.selectCard(card.id, toggle: true)
            : null,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectionMode)
              Checkbox(
                value: selected,
                onChanged: (_) =>
                    controller.selectCard(card.id, toggle: true),
              ),
            _thumbnail(card.frontRef),
          ],
        ),
        title: Text(
          card.frontRef.split(Platform.pathSeparator).last,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Icon(
              appliedBack != null ? Icons.flip_to_back : Icons.report_outlined,
              size: 14,
              color: appliedBack != null
                  ? (hasOwnBack ? Colors.teal : Colors.grey)
                  : Colors.orange,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(backLabel, overflow: TextOverflow.ellipsis),
            ),
            const Spacer(),
            if (card.count > 1) Text('×${card.count}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'detail', child: Text(Strings.detail)),
            const PopupMenuItem(value: 'back', child: Text(Strings.setBack)),
            if (hasOwnBack)
              const PopupMenuItem(
                value: 'clearBack',
                child: Text(Strings.clearBack),
              ),
            // One entry per global back so each card can pick its own.
            for (final back in project.globalBacks)
              if (card.globalBackId != back.id)
                PopupMenuItem(
                  value: 'global:${back.id}',
                  child: Text(
                    '${Strings.useGlobalBack}: '
                    '${back.ref.split(Platform.pathSeparator).last}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            if (card.globalBackId != null)
              const PopupMenuItem(
                value: 'globalDefault',
                child: Text(Strings.useDefaultBack),
              ),
            const PopupMenuItem(value: 'count', child: Text(Strings.copies)),
            const PopupMenuItem(
              value: 'remove',
              child: Text(Strings.removeCard),
            ),
          ],
          onSelected: (value) => _onAction(context, value),
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, String action) async {
    if (action.startsWith('global:')) {
      controller.setCardGlobalBack(card.id, action.substring('global:'.length));
      return;
    }
    switch (action) {
      case 'detail':
        if (!context.mounted) return;
        await showCardDetailDialog(context, controller, card.id);
      case 'back':
        final file = await openFile(acceptedTypeGroups: [imageTypeGroup]);
        if (file != null) controller.setCardBack(card.id, file.path);
      case 'clearBack':
        controller.setCardBack(card.id, null);
      case 'globalDefault':
        controller.setCardGlobalBack(card.id, null);
      case 'remove':
        controller.removeCard(card.id);
      case 'count':
        if (!context.mounted) return;
        final result = await showDialog<int>(
          context: context,
          builder: (context) => _CountDialog(initial: card.count),
        );
        if (result != null) controller.setCardCount(card.id, result);
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
