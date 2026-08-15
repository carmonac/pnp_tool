import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Resolves project image refs to bytes. Refs are either absolute paths or
/// paths relative to a base directory (e.g. the project file's folder), so
/// the core never depends on the current working directory.
abstract interface class ImageResolver {
  Future<Uint8List> readBytes(String ref);

  /// Absolute path for [ref], for display or existence checks.
  String resolvePath(String ref);
}

class FileImageResolver implements ImageResolver {
  final String? baseDir;

  const FileImageResolver({this.baseDir});

  @override
  String resolvePath(String ref) {
    if (p.isAbsolute(ref) || baseDir == null) return ref;
    return p.normalize(p.join(baseDir!, ref));
  }

  @override
  Future<Uint8List> readBytes(String ref) => File(resolvePath(ref)).readAsBytes();
}
