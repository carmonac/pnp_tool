import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists the recently opened project list in the app support directory.
class RecentProjects {
  static const _maxEntries = 10;

  Future<File> _storeFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'recent_projects.json'));
  }

  Future<List<String>> load() async {
    try {
      final file = await _storeFile();
      if (!await file.exists()) return [];
      final list = (jsonDecode(await file.readAsString()) as List)
          .cast<String>()
          .where((path) => File(path).existsSync())
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> add(String path) async {
    final list = await load()
      ..remove(path)
      ..insert(0, path);
    final file = await _storeFile();
    await file.writeAsString(jsonEncode(list.take(_maxEntries).toList()));
  }
}
