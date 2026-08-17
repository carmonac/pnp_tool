import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pnp_core/pnp_core.dart';
import 'package:pnp_studio/state/project_controller.dart';

String _repoRoot() {
  var dir = Directory.current;
  while (!Directory(p.join(dir.path, 'example', 'input')).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('example/input not found');
    dir = parent;
  }
  return dir.path;
}

void main() {
  late Directory tempDir;
  final input = p.join(_repoRoot(), 'example', 'input');

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pnp_bundle_flow');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('export .pnp then reopen it as a working project', () async {
    final controller = ProjectController(const PnpProject(
      name: 'compartible',
      mode: ProjectMode.grid,
      pageSize: SizeMm(210, 297),
    ));
    addTearDown(controller.dispose);
    controller.addCards([p.join(input, '1_front.jpg')]);
    controller.addGlobalBack(p.join(input, '1_back.jpg'));

    final bundlePath = p.join(tempDir.path, 'compartible.pnp');
    await controller.exportBundle(bundlePath);
    expect(controller.dirty, isFalse);
    expect(controller.bundlePath, bundlePath);
    expect(File(bundlePath).existsSync(), isTrue);

    final reopened = await ProjectController.loadBundle(
      bundlePath,
      extractDir: p.join(tempDir.path, 'extracted'),
    );
    addTearDown(reopened.dispose);

    expect(reopened.project.name, 'compartible');
    expect(reopened.project.cards.length, 1);
    expect(reopened.project.globalBacks.length, 1);
    // The extracted image files really exist where the refs point.
    expect(
        File(reopened.project.cards.single.frontRef).existsSync(), isTrue);
    expect(
        File(reopened.project.globalBacks.single.ref).existsSync(), isTrue);

    // Saving the reopened project rewrites the bundle in place.
    reopened.setCardCount(reopened.project.cards.single.id, 3);
    expect(reopened.dirty, isTrue);
    await reopened.save();
    expect(reopened.dirty, isFalse);

    final reread = await ProjectController.loadBundle(
      bundlePath,
      extractDir: p.join(tempDir.path, 'extracted2'),
    );
    addTearDown(reread.dispose);
    expect(reread.project.cards.single.count, 3);
  });

  test('exporting with a missing image fails with FormatException', () async {
    final controller = ProjectController(PnpProject(
      name: 'roto',
      mode: ProjectMode.grid,
      pageSize: const SizeMm(210, 297),
      cards: [
        CardItem(id: 'x', frontRef: p.join(tempDir.path, 'nope.png')),
      ],
    ));
    addTearDown(controller.dispose);

    expect(
      () => controller.exportBundle(p.join(tempDir.path, 'roto.pnp')),
      throwsFormatException,
    );
  });
}
