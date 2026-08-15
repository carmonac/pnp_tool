import 'package:flutter/material.dart';
import 'package:pnp_core/pnp_core.dart';

import '../state/project_controller.dart';
import '../strings.dart';

Future<void> showProjectSettings(
    BuildContext context, ProjectController controller) {
  return showDialog(
    context: context,
    builder: (context) => _SettingsDialog(controller: controller),
  );
}

class _SettingsDialog extends StatefulWidget {
  final ProjectController controller;

  const _SettingsDialog({required this.controller});

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late final PnpProject _initial = widget.controller.project;
  late final _bleed =
      TextEditingController(text: _initial.bleedMm.toString());
  late final _spacing =
      TextEditingController(text: _initial.spacingMm.toString());
  late bool _cutLines = _initial.drawCutLines;
  late bool _calibration = _initial.drawCalibration;
  late bool _jpeg = _initial.jpegQuality != null;
  late double _jpegQuality = (_initial.jpegQuality ?? 90).toDouble();
  late FitMode _fitMode = _initial.fitMode;

  bool get _isGrid => _initial.mode == ProjectMode.grid;

  @override
  void dispose() {
    _bleed.dispose();
    _spacing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(Strings.settings),
      content: SizedBox(
        width: 360,
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(
              controller: _bleed,
              decoration: const InputDecoration(labelText: Strings.bleedMm),
              keyboardType: TextInputType.number,
            ),
            if (_isGrid) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _spacing,
                decoration:
                    const InputDecoration(labelText: Strings.spacingMm),
                keyboardType: TextInputType.number,
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(Strings.cutLines),
              value: _cutLines,
              onChanged: (v) => setState(() => _cutLines = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(Strings.calibrationMarks),
              value: _calibration,
              onChanged: (v) => setState(() => _calibration = v),
            ),
            if (_isGrid)
              DropdownButtonFormField<FitMode>(
                initialValue: _fitMode,
                decoration:
                    const InputDecoration(labelText: Strings.fitMode),
                items: const [
                  DropdownMenuItem(
                      value: FitMode.cover, child: Text(Strings.fitCover)),
                  DropdownMenuItem(
                      value: FitMode.contain,
                      child: Text(Strings.fitContain)),
                  DropdownMenuItem(
                      value: FitMode.stretch,
                      child: Text(Strings.fitStretch)),
                ],
                onChanged: (v) => setState(() => _fitMode = v!),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(Strings.jpegQuality),
              subtitle: Text(_jpeg
                  ? _jpegQuality.round().toString()
                  : Strings.losslessPng),
              value: _jpeg,
              onChanged: (v) => setState(() => _jpeg = v),
            ),
            if (_jpeg)
              Slider(
                value: _jpegQuality,
                min: 50,
                max: 100,
                divisions: 50,
                label: _jpegQuality.round().toString(),
                onChanged: (v) => setState(() => _jpegQuality = v),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(Strings.cancel),
        ),
        FilledButton(
          onPressed: _apply,
          child: const Text(Strings.accept),
        ),
      ],
    );
  }

  void _apply() {
    final bleed = double.tryParse(_bleed.text.replaceAll(',', '.'));
    final spacing = double.tryParse(_spacing.text.replaceAll(',', '.'));
    widget.controller.updateSettings(
      bleedMm: bleed != null && bleed >= 0 ? bleed : null,
      spacingMm: spacing != null && spacing >= 0 ? spacing : null,
      drawCutLines: _cutLines,
      drawCalibration: _calibration,
      jpegQuality: _jpeg ? _jpegQuality.round() : null,
      fitMode: _fitMode,
    );
    Navigator.pop(context);
  }
}
