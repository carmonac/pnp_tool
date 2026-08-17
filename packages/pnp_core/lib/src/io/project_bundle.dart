import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../models/card_item.dart';
import '../models/free_item.dart';
import '../models/project.dart';
import 'image_resolver.dart';
import 'project_serializer.dart';

/// Self-contained shareable project file: a ZIP archive (extension `.pnp`)
/// holding `project.json` plus every referenced image under `images/`.
abstract final class ProjectBundle {
  static const fileExtension = 'pnp';
  static const projectEntryName = 'project.json';
  static const imagesDirName = 'images';

  /// Packs [project] and all its images into archive bytes.
  ///
  /// Throws [FormatException] listing any image files that cannot be read.
  static Future<Uint8List> encode(
    PnpProject project, {
    ImageResolver resolver = const FileImageResolver(),
  }) async {
    // Assign a unique archive path per distinct source ref.
    final archivePaths = <String, String>{};
    final usedNames = <String>{};
    for (final ref in _collectRefs(project)) {
      if (archivePaths.containsKey(ref)) continue;
      var name = p.basename(ref);
      var counter = 1;
      while (!usedNames.add(name.toLowerCase())) {
        name = '${p.basenameWithoutExtension(ref)}_'
            '${++counter}${p.extension(ref)}';
      }
      archivePaths[ref] = '$imagesDirName/$name';
    }

    final missing = <String>[];
    final archive = Archive();
    for (final entry in archivePaths.entries) {
      try {
        final bytes = await resolver.readBytes(entry.key);
        archive.addFile(ArchiveFile(entry.value, bytes.length, bytes));
      } catch (_) {
        missing.add(entry.key);
      }
    }
    if (missing.isNotEmpty) {
      throw FormatException(
          'Missing image files: ${missing.join(', ')}');
    }

    final rewritten = _mapRefs(project, (ref) => archivePaths[ref]!);
    final json = utf8.encode(const ProjectSerializer().encode(rewritten));
    archive.addFile(ArchiveFile(projectEntryName, json.length, json));

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Unpacks archive [bytes] into [extractDir] and returns the project with
  /// its refs pointing at the extracted files.
  ///
  /// Throws [FormatException] if the archive is not a project bundle.
  static Future<PnpProject> decode(
    Uint8List bytes, {
    required String extractDir,
  }) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('Not a valid .pnp project file');
    }

    String? projectJson;
    for (final file in archive.files) {
      if (!file.isFile) continue;
      if (file.name == projectEntryName) {
        projectJson = utf8.decode(file.content as List<int>);
        continue;
      }
      // Reject entries that would escape the extraction directory.
      final target = p.normalize(p.join(extractDir, file.name));
      if (!p.isWithin(extractDir, target)) continue;
      final out = File(target);
      await out.parent.create(recursive: true);
      await out.writeAsBytes(file.content as List<int>);
    }

    if (projectJson == null) {
      throw const FormatException(
          'Not a valid .pnp project file (missing $projectEntryName)');
    }

    return ProjectSerializer(baseDir: extractDir).decode(projectJson);
  }

  static Iterable<String> _collectRefs(PnpProject project) sync* {
    for (final card in project.cards) {
      yield card.frontRef;
      if (card.backRef != null) yield card.backRef!;
    }
    for (final back in project.globalBacks) {
      yield back.ref;
    }
    for (final page in project.pages) {
      for (final item in page.items) {
        yield item.frontRef;
        if (item.backRef != null) yield item.backRef!;
      }
    }
  }

  static PnpProject _mapRefs(
      PnpProject project, String Function(String) map) {
    return project.copyWith(
      cards: [
        for (final card in project.cards)
          CardItem(
            id: card.id,
            frontRef: map(card.frontRef),
            backRef: card.backRef == null ? null : map(card.backRef!),
            globalBackId: card.globalBackId,
            count: card.count,
          ),
      ],
      globalBacks: [
        for (final back in project.globalBacks)
          GlobalBack(id: back.id, ref: map(back.ref)),
      ],
      pages: [
        for (final page in project.pages)
          FreePage(items: [
            for (final item in page.items)
              FreeItem(
                id: item.id,
                frontRef: map(item.frontRef),
                backRef: item.backRef == null ? null : map(item.backRef!),
                position: item.position,
                size: item.size,
              ),
          ]),
      ],
    );
  }
}
