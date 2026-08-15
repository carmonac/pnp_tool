import 'dart:io';

import 'package:path/path.dart' as p;

import '../layout/natural_sort.dart';
import '../models/card_item.dart';

const _frontSuffix = '_front';
const _backSuffix = '_back';
const _globalBackName = 'global_back';
const _imageExtensions = {'.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'};

class DiscoveryResult {
  final List<CardItem> cards;
  final String? globalBackRef;

  const DiscoveryResult({required this.cards, this.globalBackRef});
}

/// Scans a directory for `<name>_front.<ext>` / `<name>_back.<ext>` pairs and
/// an optional `global_back.<ext>` fallback, in natural sort order.
///
/// Throws [FormatException] if a back has no matching front, or — when
/// [requireBacks] is true — if a front has neither its own back nor a global
/// back to fall back on.
Future<DiscoveryResult> discoverCards(
  String inputDir, {
  bool requireBacks = true,
}) async {
  final directory = Directory(inputDir);
  if (!await directory.exists()) {
    throw FormatException('Input directory not found: $inputDir');
  }

  String? globalBackPath;
  final frontFiles = <String, String>{};
  final backFiles = <String, String>{};

  await for (final entry in directory.list()) {
    if (entry is! File) continue;
    if (!_imageExtensions.contains(p.extension(entry.path).toLowerCase())) {
      continue;
    }
    final name = p.basenameWithoutExtension(entry.path).toLowerCase();
    if (name == _globalBackName) {
      globalBackPath = entry.path;
    } else if (name.endsWith(_frontSuffix)) {
      frontFiles[name.substring(0, name.length - _frontSuffix.length)] =
          entry.path;
    } else if (name.endsWith(_backSuffix)) {
      backFiles[name.substring(0, name.length - _backSuffix.length)] =
          entry.path;
    }
  }

  for (final backName in backFiles.keys) {
    if (!frontFiles.containsKey(backName)) {
      throw FormatException('Front side not found for: $backName$_backSuffix');
    }
  }

  final sortedKeys = frontFiles.keys.toList()..sort(compareNatural);

  final cards = <CardItem>[];
  for (final name in sortedKeys) {
    final backPath = backFiles[name];
    if (backPath == null && globalBackPath == null && requireBacks) {
      throw FormatException(
          'Back side not found for: $name$_frontSuffix and no global_back '
          'image is available.');
    }
    cards.add(CardItem(
      id: name,
      frontRef: frontFiles[name]!,
      backRef: backPath,
    ));
  }

  return DiscoveryResult(cards: cards, globalBackRef: globalBackPath);
}
