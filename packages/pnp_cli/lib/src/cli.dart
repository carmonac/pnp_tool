import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:pnp_core/pnp_core.dart';

const _usageHeader = '''
Prepare print-and-play card sheets as duplex-ready PDFs.

Usage:
  pnp_tool [options] <inputDir> <output.pdf>
  pnp_tool --project <file.pnp.json> <output.pdf>

The input directory must contain images named <name>_front.<ext> and
optionally <name>_back.<ext>; cards without their own back use
global_back.<ext> when present.

Options:''';

ArgParser buildParser() => ArgParser()
  ..addOption('project',
      help: 'Render a saved .pnp.json project instead of scanning a directory.')
  ..addOption('page',
      defaultsTo: 'a4',
      help: 'Page size: a preset (a4, a3, a5, letter, legal) or WxH in mm.')
  ..addOption('card',
      defaultsTo: 'poker',
      help: 'Card size: a preset (poker, bridge, tarot, miniUs, miniEuro, '
          'stdEuro, square) or WxH in mm.')
  ..addOption('bleed', defaultsTo: '1.0', help: 'Bleed in mm.')
  ..addOption('spacing', defaultsTo: '4.0', help: 'Card spacing in mm.')
  ..addOption('jpeg-quality',
      defaultsTo: '90',
      help: 'JPEG quality (1-100) for embedded images, or "png" for lossless.')
  ..addFlag('cut-lines',
      defaultsTo: true, help: 'Draw cut marks in the page margins.')
  ..addFlag('calibration',
      defaultsTo: true, help: 'Draw calibration and registration marks.')
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

Future<int> run(List<String> arguments) async {
  final parser = buildParser();
  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(parser.usage);
    return 64;
  }

  if (args.flag('help')) {
    stdout.writeln(_usageHeader);
    stdout.writeln(parser.usage);
    return 0;
  }

  try {
    final projectPath = args.option('project');
    if (projectPath != null) {
      if (args.rest.length != 1) {
        stderr.writeln('Expected exactly one output path with --project.');
        return 64;
      }
      final project = ProjectSerializer(baseDir: p.dirname(projectPath))
          .decode(await File(projectPath).readAsString());
      await _generate(project, args.rest.single);
      return 0;
    }

    if (args.rest.length != 2) {
      stderr.writeln(_usageHeader);
      stderr.writeln(parser.usage);
      return 64;
    }

    final [inputDir, outputPath] = args.rest;
    final discovery = await discoverCards(inputDir);

    int? jpegQuality;
    final qualityRaw = args.option('jpeg-quality')!;
    if (qualityRaw != 'png') {
      jpegQuality = int.tryParse(qualityRaw);
      if (jpegQuality == null || jpegQuality < 1 || jpegQuality > 100) {
        stderr.writeln('Invalid --jpeg-quality: $qualityRaw');
        return 64;
      }
    }

    final project = PnpProject(
      name: p.basename(inputDir),
      mode: ProjectMode.grid,
      pageSize: _parseSize(args.option('page')!, _pagePresets, 'page'),
      cardSize: _parseSize(args.option('card')!, _cardPresets, 'card'),
      bleedMm: _parseDouble(args.option('bleed')!, 'bleed'),
      spacingMm: _parseDouble(args.option('spacing')!, 'spacing'),
      drawCutLines: args.flag('cut-lines'),
      drawCalibration: args.flag('calibration'),
      jpegQuality: jpegQuality,
      cards: discovery.cards,
      globalBacks: discovery.globalBackRef == null
          ? const []
          : [GlobalBack(id: 'global', ref: discovery.globalBackRef!)],
    );
    await _generate(project, outputPath);
    return 0;
  } on Exception catch (e) {
    stderr.writeln('Error: $e');
    return 1;
  }
}

Future<void> _generate(PnpProject project, String outputPath) async {
  final generator = PdfGenerator(
    project: project,
    resolver: const FileImageResolver(),
  );
  final bytes = await generator.generate(
    onProgress: (page, total) => stdout.writeln('Page $page/$total'),
  );
  await File(outputPath).writeAsBytes(bytes);
  stdout.writeln('Wrote $outputPath (${(bytes.length / 1024).round()} KB)');
}

Map<String, SizeMm> get _pagePresets => {
      for (final preset in PagePreset.values)
        if (preset.size != null) preset.name.toLowerCase(): preset.size!,
    };

Map<String, SizeMm> get _cardPresets => {
      for (final preset in CardPreset.values)
        if (preset.size != null) preset.name.toLowerCase(): preset.size!,
    };

SizeMm _parseSize(String raw, Map<String, SizeMm> presets, String label) {
  final preset = presets[raw.toLowerCase()];
  if (preset != null) return preset;
  final parts = raw.toLowerCase().split('x');
  if (parts.length == 2) {
    final width = double.tryParse(parts[0]);
    final height = double.tryParse(parts[1]);
    if (width != null && height != null && width > 0 && height > 0) {
      return SizeMm(width, height);
    }
  }
  throw FormatException(
      'Invalid --$label "$raw". Use a preset (${presets.keys.join(', ')}) '
      'or WxH in mm, e.g. 63.5x88.9.');
}

double _parseDouble(String raw, String label) {
  final value = double.tryParse(raw);
  if (value == null || value < 0) {
    throw FormatException('Invalid --$label "$raw".');
  }
  return value;
}
