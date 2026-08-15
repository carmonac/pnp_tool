// Regenerates lib/src/pdf/resources.g.dart from the PNGs in the repository's
// resources/ directory, embedding them so compiled binaries need no files on
// disk. Run from the repo root:
//
//   dart run packages/pnp_core/tool/generate_resources.dart
import 'dart:convert';
import 'dart:io';

const _assets = {
  'calibrPng': 'resources/calibr.png',
  'calibrPosPng': 'resources/calibr_pos.png',
  'logoPng': 'resources/logo.png',
};

void main() {
  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE - do not edit by hand.')
    ..writeln('// Regenerate with: '
        'dart run packages/pnp_core/tool/generate_resources.dart')
    ..writeln("import 'dart:convert';")
    ..writeln("import 'dart:typed_data';")
    ..writeln();

  _assets.forEach((name, path) {
    final bytes = File(path).readAsBytesSync();
    final b64 = base64Encode(bytes);
    buffer.writeln('final Uint8List $name = base64Decode(');
    for (var i = 0; i < b64.length; i += 76) {
      final chunk = b64.substring(i, i + 76 > b64.length ? b64.length : i + 76);
      final isLast = i + 76 >= b64.length;
      buffer.writeln("  '$chunk'${isLast ? ',' : ''}");
    }
    buffer
      ..writeln(');')
      ..writeln();
  });

  File('packages/pnp_core/lib/src/pdf/resources.g.dart')
      .writeAsStringSync(buffer.toString());
  stdout.writeln('Wrote resources.g.dart');
}
