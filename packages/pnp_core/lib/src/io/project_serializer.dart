import 'dart:convert';

import 'package:path/path.dart' as p;

import '../models/card_item.dart';
import '../models/free_item.dart';
import '../models/geometry.dart';
import '../models/presets.dart';
import '../models/project.dart';

/// Serializes projects to versioned JSON. Image refs are stored relative to
/// the project file's directory ([baseDir]) when possible, so a project
/// folder can be moved or shared as a whole.
class ProjectSerializer {
  final String? baseDir;

  const ProjectSerializer({this.baseDir});

  String encode(PnpProject project) =>
      const JsonEncoder.withIndent('  ').convert(toJson(project));

  PnpProject decode(String source) =>
      fromJson(jsonDecode(source) as Map<String, dynamic>);

  Map<String, dynamic> toJson(PnpProject project) => {
        'schemaVersion': PnpProject.currentSchemaVersion,
        'name': project.name,
        'mode': project.mode.name,
        'page': _sizeToJson(project.pageSize, PagePreset.match(project.pageSize).name),
        'bleedMm': project.bleedMm,
        'cutLines': project.drawCutLines,
        'calibration': project.drawCalibration,
        'jpegQuality': project.jpegQuality,
        'fitMode': project.fitMode.name,
        if (project.mode == ProjectMode.grid) ...{
          'card':
              _sizeToJson(project.cardSize, CardPreset.match(project.cardSize).name),
          'spacingMm': project.spacingMm,
          'minMarginMm': project.minMarginMm,
          'cards': [
            for (final card in project.cards)
              {
                'id': card.id,
                'front': _relativize(card.frontRef),
                'back': card.backRef == null ? null : _relativize(card.backRef!),
                'count': card.count,
              },
          ],
          'globalBack': project.globalBackRef == null
              ? null
              : _relativize(project.globalBackRef!),
        },
        if (project.mode == ProjectMode.freeform)
          'pages': [
            for (final page in project.pages)
              {
                'items': [
                  for (final item in page.items)
                    {
                      'id': item.id,
                      'front': _relativize(item.frontRef),
                      'back':
                          item.backRef == null ? null : _relativize(item.backRef!),
                      'x': item.position.x,
                      'y': item.position.y,
                      'widthMm': item.size.width,
                      'heightMm': item.size.height,
                    },
                ],
              },
          ],
      };

  PnpProject fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'] as int? ?? 1;
    if (version > PnpProject.currentSchemaVersion) {
      throw FormatException(
          'Project schema version $version is newer than supported '
          '(${PnpProject.currentSchemaVersion}). Update the application.');
    }

    final mode = ProjectMode.values.byName(json['mode'] as String? ?? 'grid');

    return PnpProject(
      name: json['name'] as String? ?? 'Untitled',
      mode: mode,
      pageSize: _sizeFromJson(
          json['page'] as Map<String, dynamic>?, PagePreset.a4.size!),
      bleedMm: (json['bleedMm'] as num?)?.toDouble() ?? 1.0,
      drawCutLines: json['cutLines'] as bool? ?? true,
      drawCalibration: json['calibration'] as bool? ?? true,
      jpegQuality: json['jpegQuality'] as int?,
      fitMode: FitMode.values.byName(json['fitMode'] as String? ?? 'cover'),
      cardSize: _sizeFromJson(
          json['card'] as Map<String, dynamic>?, CardPreset.poker.size!),
      spacingMm: (json['spacingMm'] as num?)?.toDouble() ?? 4.0,
      minMarginMm: (json['minMarginMm'] as num?)?.toDouble() ?? 5.0,
      cards: [
        for (final item in json['cards'] as List? ?? const [])
          CardItem(
            id: item['id'] as String,
            frontRef: _resolve(item['front'] as String),
            backRef: item['back'] == null ? null : _resolve(item['back'] as String),
            count: item['count'] as int? ?? 1,
          ),
      ],
      globalBackRef: json['globalBack'] == null
          ? null
          : _resolve(json['globalBack'] as String),
      pages: [
        for (final page in json['pages'] as List? ?? const [])
          FreePage(items: [
            for (final item in page['items'] as List? ?? const [])
              FreeItem(
                id: item['id'] as String,
                frontRef: _resolve(item['front'] as String),
                backRef:
                    item['back'] == null ? null : _resolve(item['back'] as String),
                position: PointMm((item['x'] as num).toDouble(),
                    (item['y'] as num).toDouble()),
                size: SizeMm((item['widthMm'] as num).toDouble(),
                    (item['heightMm'] as num).toDouble()),
              ),
          ]),
        if ((json['pages'] as List?)?.isEmpty ?? true)
          if (mode == ProjectMode.freeform) const FreePage(),
      ],
    );
  }

  Map<String, dynamic> _sizeToJson(SizeMm size, String presetName) =>
      presetName == 'custom'
          ? {'preset': 'custom', 'widthMm': size.width, 'heightMm': size.height}
          : {'preset': presetName};

  SizeMm _sizeFromJson(Map<String, dynamic>? json, SizeMm fallback) {
    if (json == null) return fallback;
    final presetName = json['preset'] as String? ?? 'custom';
    if (presetName != 'custom') {
      final size =
          PagePreset.fromName(presetName)?.size ?? CardPreset.fromName(presetName)?.size;
      if (size != null) return size;
    }
    final width = (json['widthMm'] as num?)?.toDouble();
    final height = (json['heightMm'] as num?)?.toDouble();
    if (width == null || height == null) return fallback;
    return SizeMm(width, height);
  }

  String _relativize(String ref) {
    if (baseDir == null || !p.isAbsolute(ref)) return ref;
    final relative = p.relative(ref, from: baseDir);
    // Keep absolute paths that would escape far outside the project folder.
    return relative.startsWith('..${p.separator}..${p.separator}..')
        ? ref
        : relative;
  }

  String _resolve(String ref) {
    if (baseDir == null || p.isAbsolute(ref)) return ref;
    return p.normalize(p.join(baseDir!, ref));
  }
}
