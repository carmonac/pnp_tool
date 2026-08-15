import 'package:flutter/material.dart';
import 'package:pnp_core/pnp_core.dart';

import '../strings.dart';

/// Result of the new-project dialog.
class NewProjectConfig {
  final String name;
  final SizeMm pageSize;
  final SizeMm? cardSize; // null for freeform

  const NewProjectConfig({
    required this.name,
    required this.pageSize,
    this.cardSize,
  });
}

Future<NewProjectConfig?> showNewProjectDialog(
    BuildContext context, {required ProjectMode mode}) {
  return showDialog<NewProjectConfig>(
    context: context,
    builder: (context) => _NewProjectDialog(mode: mode),
  );
}

class _NewProjectDialog extends StatefulWidget {
  final ProjectMode mode;

  const _NewProjectDialog({required this.mode});

  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  final _name = TextEditingController();
  PagePreset _pagePreset = PagePreset.a4;
  CardPreset _cardPreset = CardPreset.poker;
  final _pageWidth = TextEditingController();
  final _pageHeight = TextEditingController();
  final _cardWidth = TextEditingController();
  final _cardHeight = TextEditingController();
  String? _error;

  bool get _isGrid => widget.mode == ProjectMode.grid;

  @override
  void dispose() {
    for (final c in [_name, _pageWidth, _pageHeight, _cardWidth, _cardHeight]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          _isGrid ? Strings.newGridProject : Strings.newFreeformProject),
      content: SizedBox(
        width: 380,
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: Strings.projectName),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PagePreset>(
              initialValue: _pagePreset,
              decoration: const InputDecoration(labelText: Strings.pageSize),
              items: [
                for (final preset in PagePreset.values)
                  DropdownMenuItem(
                      value: preset, child: Text(preset.label)),
              ],
              onChanged: (v) => setState(() => _pagePreset = v!),
            ),
            if (_pagePreset == PagePreset.custom)
              _customSizeRow(_pageWidth, _pageHeight),
            if (_isGrid) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<CardPreset>(
                initialValue: _cardPreset,
                decoration:
                    const InputDecoration(labelText: Strings.cardSize),
                items: [
                  for (final preset in CardPreset.values)
                    DropdownMenuItem(
                        value: preset, child: Text(preset.label)),
                ],
                onChanged: (v) => setState(() => _cardPreset = v!),
              ),
              if (_cardPreset == CardPreset.custom)
                _customSizeRow(_cardWidth, _cardHeight),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error),
                ),
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
          onPressed: _create,
          child: const Text(Strings.create),
        ),
      ],
    );
  }

  Widget _customSizeRow(
      TextEditingController width, TextEditingController height) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: width,
              decoration: const InputDecoration(labelText: Strings.widthMm),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: height,
              decoration: const InputDecoration(labelText: Strings.heightMm),
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    );
  }

  SizeMm? _parseCustom(
      TextEditingController width, TextEditingController height) {
    final w = double.tryParse(width.text.replaceAll(',', '.'));
    final h = double.tryParse(height.text.replaceAll(',', '.'));
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return SizeMm(w, h);
  }

  void _create() {
    final pageSize = _pagePreset == PagePreset.custom
        ? _parseCustom(_pageWidth, _pageHeight)
        : _pagePreset.size;
    if (pageSize == null) {
      setState(() => _error = Strings.invalidSize);
      return;
    }

    SizeMm? cardSize;
    if (_isGrid) {
      cardSize = _cardPreset == CardPreset.custom
          ? _parseCustom(_cardWidth, _cardHeight)
          : _cardPreset.size;
      if (cardSize == null) {
        setState(() => _error = Strings.invalidSize);
        return;
      }
      // Validate the card actually fits before creating the project.
      try {
        computeGridGeometry(PnpProject(
          name: 'check',
          mode: ProjectMode.grid,
          pageSize: pageSize,
          cardSize: cardSize,
        ));
      } on ArgumentError {
        setState(() => _error = Strings.cardDoesNotFit);
        return;
      }
    }

    final name = _name.text.trim().isEmpty
        ? (_isGrid ? 'cartas' : 'forma-libre')
        : _name.text.trim();

    Navigator.pop(
      context,
      NewProjectConfig(name: name, pageSize: pageSize, cardSize: cardSize),
    );
  }
}
