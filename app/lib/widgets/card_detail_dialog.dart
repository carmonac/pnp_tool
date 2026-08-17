import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pnp_core/pnp_core.dart';

import '../state/project_controller.dart';
import '../strings.dart';
import 'card_list_sidebar.dart' show imageTypeGroup;
import 'image_drop_dialog.dart';

/// Sentinel radio value for the "add a new global back" option.
const _addNewValue = '__add_new__';

Future<void> showCardDetailDialog(
    BuildContext context, ProjectController controller, String cardId) {
  return showDialog(
    context: context,
    builder: (context) =>
        CardDetailDialog(controller: controller, cardId: cardId),
  );
}

/// Card detail modal: front preview next to the back preview (droppable to
/// replace the back), plus a global-back selector with an inline option to
/// add a new global back by drag & drop.
class CardDetailDialog extends StatefulWidget {
  final ProjectController controller;
  final String cardId;

  const CardDetailDialog({
    super.key,
    required this.controller,
    required this.cardId,
  });

  @override
  State<CardDetailDialog> createState() => _CardDetailDialogState();
}

class _CardDetailDialogState extends State<CardDetailDialog> {
  bool? _showGlobalPicker;
  bool _addingNew = false;

  ProjectController get controller => widget.controller;

  CardItem? get _card {
    for (final card in controller.project.cards) {
      if (card.id == widget.cardId) return card;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final card = _card;
        if (card == null) {
          // Card removed while the dialog was open.
          return const SizedBox.shrink();
        }
        final project = controller.project;
        final appliedBack = project.backRefFor(card);
        _showGlobalPicker ??=
            card.backRef == null && project.globalBacks.isNotEmpty;

        final effectiveGlobalId = _addingNew
            ? _addNewValue
            : (card.backRef != null
                ? null
                : (card.globalBackId ??
                    (project.globalBacks.isEmpty
                        ? null
                        : project.globalBacks.first.id)));

        return AlertDialog(
          title: Text(
            p.basename(card.frontRef),
            overflow: TextOverflow.ellipsis,
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _PreviewPane(
                          label: Strings.front,
                          path: card.frontRef,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _BackDropPane(
                          path: appliedBack,
                          isOwnBack: card.backRef != null,
                          onImage: (path) {
                            controller.setCardBack(card.id, path);
                            setState(() {
                              _showGlobalPicker = false;
                              _addingNew = false;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(Strings.selectGlobalBackCheck),
                    value: _showGlobalPicker!,
                    onChanged: (value) =>
                        setState(() => _showGlobalPicker = value ?? false),
                  ),
                  if (_showGlobalPicker!) ...[
                    RadioGroup<String>(
                      groupValue: effectiveGlobalId,
                      onChanged: (value) {
                        if (value == _addNewValue) {
                          setState(() => _addingNew = true);
                        } else if (value != null) {
                          setState(() => _addingNew = false);
                          controller.setCardGlobalBack(card.id, value);
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final back in project.globalBacks)
                            RadioListTile<String>(
                              value: back.id,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Row(
                                children: [
                                  _smallThumbnail(back.ref),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      p.basename(back.ref),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const RadioListTile<String>(
                            value: _addNewValue,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(Strings.addNewGlobalBack),
                          ),
                        ],
                      ),
                    ),
                    if (_addingNew)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: ImageDropZone(
                          allowMultiple: false,
                          height: 110,
                          onPicked: (paths) {
                            final id = controller.addGlobalBack(paths.first);
                            controller.setCardGlobalBack(card.id, id);
                            setState(() => _addingNew = false);
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(Strings.close),
            ),
          ],
        );
      },
    );
  }
}

class _PreviewPane extends StatelessWidget {
  final String label;
  final String? path;

  const _PreviewPane({required this.label, required this.path});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Container(
          height: 240,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: path == null
              ? Center(
                  child: Text(
                    Strings.noBack,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.file(
                    File(path!),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
        ),
        if (path != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              p.basename(path!),
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

/// Back preview that accepts a dropped image (or a click to pick one) to
/// replace this card's own back.
class _BackDropPane extends StatefulWidget {
  final String? path;
  final bool isOwnBack;
  final void Function(String path) onImage;

  const _BackDropPane({
    required this.path,
    required this.isOwnBack,
    required this.onImage,
  });

  @override
  State<_BackDropPane> createState() => _BackDropPaneState();
}

class _BackDropPaneState extends State<_BackDropPane> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DropTarget(
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: (details) {
        setState(() => _hovering = false);
        final paths = filterImagePaths(details.files.map((f) => f.path));
        if (paths.isNotEmpty) widget.onImage(paths.first);
      },
      child: InkWell(
        onTap: () async {
          final file = await openFile(acceptedTypeGroups: [imageTypeGroup]);
          if (file != null) widget.onImage(file.path);
        },
        borderRadius: BorderRadius.circular(6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: _hovering
                ? Border.all(color: scheme.primary, width: 2)
                : null,
          ),
          child: _PreviewPane(
            label: widget.isOwnBack
                ? Strings.back
                : '${Strings.back} · ${Strings.globalBack.toLowerCase()}',
            path: widget.path,
          ),
        ),
      ),
    );
  }
}

Widget _smallThumbnail(String path) => ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.file(
        File(path),
        width: 28,
        height: 39,
        fit: BoxFit.cover,
        cacheWidth: 56,
        errorBuilder: (context, error, stack) =>
            const Icon(Icons.broken_image_outlined, size: 20),
      ),
    );
