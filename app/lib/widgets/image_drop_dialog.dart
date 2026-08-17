import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../strings.dart';
import 'card_list_sidebar.dart' show imageTypeGroup;

const _imageExtensions = {'.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'};

List<String> filterImagePaths(Iterable<String> paths) => [
      for (final path in paths)
        if (_imageExtensions.contains(p.extension(path).toLowerCase())) path,
    ];

/// Modal with a drop zone; dropping image files or clicking (file picker)
/// resolves with the chosen paths. Returns null when dismissed.
Future<List<String>?> showImageDropDialog(
  BuildContext context, {
  required String title,
  bool allowMultiple = true,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 380,
        child: ImageDropZone(
          allowMultiple: allowMultiple,
          onPicked: (paths) => Navigator.pop(context, paths),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(Strings.cancel),
        ),
      ],
    ),
  );
}

/// Dashed-style drop area that also opens the file picker on click.
class ImageDropZone extends StatefulWidget {
  final bool allowMultiple;
  final void Function(List<String> paths) onPicked;
  final double height;

  const ImageDropZone({
    super.key,
    required this.onPicked,
    this.allowMultiple = true,
    this.height = 140,
  });

  @override
  State<ImageDropZone> createState() => _ImageDropZoneState();
}

class _ImageDropZoneState extends State<ImageDropZone> {
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
        if (paths.isNotEmpty) {
          widget.onPicked(widget.allowMultiple ? paths : [paths.first]);
        }
      },
      child: InkWell(
        onTap: () async {
          if (widget.allowMultiple) {
            final files = await openFiles(acceptedTypeGroups: [imageTypeGroup]);
            if (files.isNotEmpty) {
              widget.onPicked(files.map((f) => f.path).toList());
            }
          } else {
            final file = await openFile(acceptedTypeGroups: [imageTypeGroup]);
            if (file != null) widget.onPicked([file.path]);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: _hovering
                ? scheme.primaryContainer.withValues(alpha: 0.4)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovering ? scheme.primary : scheme.outlineVariant,
              width: _hovering ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file_outlined,
                  size: 32, color: scheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.allowMultiple
                      ? Strings.dropImagesHint
                      : Strings.dropImageHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
