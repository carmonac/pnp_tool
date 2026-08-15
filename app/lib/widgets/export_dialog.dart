import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../state/project_controller.dart';
import '../strings.dart';

/// Asks for a destination, generates the PDF off the UI thread with a
/// progress dialog, and reports the result.
Future<void> exportPdfFlow(
    BuildContext context, ProjectController controller) async {
  final location = await getSaveLocation(
    suggestedName: '${controller.project.name}.pdf',
    acceptedTypeGroups: const [
      XTypeGroup(label: 'PDF', extensions: ['pdf']),
    ],
  );
  if (location == null || !context.mounted) return;

  final progress = ValueNotifier<(int, int)?>(null);
  var dialogOpen = true;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text(Strings.exporting),
      content: ValueListenableBuilder(
        valueListenable: progress,
        builder: (context, value, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: value == null ? null : value.$1 / value.$2,
            ),
            const SizedBox(height: 12),
            Text(value == null
                ? '…'
                : '${Strings.page} ${value.$1} / ${value.$2}'),
          ],
        ),
      ),
    ),
  );

  try {
    final bytes = await controller.exportPdf(
      onProgress: (page, total) => progress.value = (page, total),
    );
    await File(location.path).writeAsBytes(bytes);
    if (context.mounted && dialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
      dialogOpen = false;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${Strings.exportDone}: ${location.path} '
            '(${(bytes.length / 1024).round()} KB)'),
      ));
    }
  } catch (e) {
    if (context.mounted && dialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
      dialogOpen = false;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${Strings.exportFailed}: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }
}
