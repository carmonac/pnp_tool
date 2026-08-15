import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/project_controller.dart';
import '../strings.dart';
import 'card_list_sidebar.dart' show imageTypeGroup;

/// Freeform-mode sidebar: images on the current sheet plus page management.
class FreeformSidebar extends StatelessWidget {
  const FreeformSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final sheetIndex = controller.selectedSheetIndex;
    final items = sheetIndex < controller.project.pages.length
        ? controller.project.pages[sheetIndex].items
        : const [];

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
                      '${Strings.items} (${items.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: Strings.addImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    onPressed: () => _pickImages(controller, sheetIndex),
                  ),
                  IconButton(
                    tooltip: Strings.addPage,
                    icon: const Icon(Icons.note_add_outlined),
                    onPressed: controller.addPage,
                  ),
                  IconButton(
                    tooltip: Strings.removePage,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: controller.project.pages.length > 1
                        ? () => controller.removePage(sheetIndex)
                        : null,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = controller.selectedItemId == item.id;
                  return ListTile(
                    dense: true,
                    selected: selected,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(
                        File(item.frontRef),
                        width: 36,
                        height: 50,
                        fit: BoxFit.cover,
                        cacheWidth: 72,
                        errorBuilder: (context, error, stack) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                    title: Text(
                      item.frontRef.split(Platform.pathSeparator).last,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${item.size.width.toStringAsFixed(1)} × '
                      '${item.size.height.toStringAsFixed(1)} mm'
                      '${item.backRef != null ? '  ·  ${Strings.back}' : ''}',
                    ),
                    onTap: () => controller.selectItem(item.id),
                    trailing: PopupMenuButton<String>(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'back',
                          child: Text(Strings.setBack),
                        ),
                        if (item.backRef != null)
                          const PopupMenuItem(
                            value: 'clearBack',
                            child: Text(Strings.clearBack),
                          ),
                        const PopupMenuItem(
                          value: 'remove',
                          child: Text(Strings.removeItem),
                        ),
                      ],
                      onSelected: (value) async {
                        switch (value) {
                          case 'back':
                            final file = await openFile(
                              acceptedTypeGroups: [imageTypeGroup],
                            );
                            if (file != null) {
                              controller.setItemBack(item.id, file.path);
                            }
                          case 'clearBack':
                            controller.setItemBack(item.id, null);
                          case 'remove':
                            controller.removeItem(item.id);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImages(ProjectController controller, int sheetIndex) async {
    final files = await openFiles(acceptedTypeGroups: [imageTypeGroup]);
    for (final file in files) {
      await controller.addFreeItem(sheetIndex, file.path);
    }
  }
}
