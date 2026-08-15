import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pnp_core/pnp_core.dart';
import 'package:test/test.dart';

void main() {
  test('generates a PDF from the example input', () async {
    final repoRoot = _findRepoRoot();
    final inputDir = p.join(repoRoot, 'example', 'input');
    final discovery = await discoverCards(inputDir);

    final project = PnpProject(
      name: 'example',
      mode: ProjectMode.grid,
      pageSize: PagePreset.a4.size!,
      cards: discovery.cards,
      globalBacks: discovery.globalBackRef == null ? const [] : [GlobalBack(id: 'global', ref: discovery.globalBackRef!)],
    );

    final bytes = await PdfGenerator(
      project: project,
      resolver: const FileImageResolver(),
    ).generate();

    expect(bytes.length, greaterThan(1000));
    // %PDF magic header.
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');

    // 4 cards, 9 per page -> 1 sheet -> 2 pages (front + back).
    final content = String.fromCharCodes(bytes);
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(content).length, 2);
  });

  test('progress callback covers every page', () async {
    final repoRoot = _findRepoRoot();
    final discovery =
        await discoverCards(p.join(repoRoot, 'example', 'input'));
    final project = PnpProject(
      name: 'example',
      mode: ProjectMode.grid,
      pageSize: PagePreset.a4.size!,
      cards: discovery.cards,
      globalBacks: discovery.globalBackRef == null ? const [] : [GlobalBack(id: 'global', ref: discovery.globalBackRef!)],
    );

    final seen = <int>[];
    await PdfGenerator(project: project, resolver: const FileImageResolver())
        .generate(onProgress: (page, total) {
      seen.add(page);
      expect(total, 2);
    });
    expect(seen, [1, 2]);
  });
}

String _findRepoRoot() {
  var dir = Directory.current;
  while (!File(p.join(dir.path, 'pubspec.yaml')).existsSync() ||
      !Directory(p.join(dir.path, 'example')).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Repo root not found from ${Directory.current}');
    }
    dir = parent;
  }
  return dir.path;
}
