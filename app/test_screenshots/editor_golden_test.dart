// Offscreen renders of the editor for visual verification during
// development. Run explicitly (not part of `flutter test`):
//
//   flutter test test_screenshots --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pnp_core/pnp_core.dart';
import 'package:pnp_studio/screens/editor_screen.dart';
import 'package:pnp_studio/state/project_controller.dart';
import 'package:pnp_studio/theme.dart';
import 'package:pnp_studio/widgets/card_detail_dialog.dart';

String _repoRoot() {
  var dir = Directory.current;
  while (!Directory(p.join(dir.path, 'example', 'input')).existsSync()) {
    dir = dir.parent;
  }
  return dir.path;
}

Future<void> _capture(
    WidgetTester tester, ProjectController controller, String name) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.runAsync(() async {
    await tester.pumpWidget(
        MaterialApp(
            theme: desktopTheme(Brightness.light),
            home: EditorScreen(controller: controller)));
    // Let PreviewImageCache finish decoding thumbnails.
    await Future<void>.delayed(const Duration(milliseconds: 2500));
  });
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(EditorScreen),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  final input = p.join(_repoRoot(), 'example', 'input');

  testWidgets('grid editor render', (tester) async {
    final controller = ProjectController(const PnpProject(
      name: 'demo rejilla',
      mode: ProjectMode.grid,
      pageSize: SizeMm(210, 297),
    ));
    addTearDown(controller.dispose);
    controller.addCards([
      for (final n in ['1', '2', '3', '4']) p.join(input, '${n}_front.jpg'),
    ]);
    controller.addGlobalBack(p.join(input, '1_back.jpg'));
    final c4 = controller.project.cards[3];
    controller.setCardBack(c4.id, p.join(input, '4_back.jpg'));

    await _capture(tester, controller, 'grid_editor');
  });

  testWidgets('grid editor back page render', (tester) async {
    final controller = ProjectController(const PnpProject(
      name: 'demo rejilla',
      mode: ProjectMode.grid,
      pageSize: SizeMm(210, 297),
    ));
    addTearDown(controller.dispose);
    controller.addCards([
      for (final n in ['1', '2', '3', '4']) p.join(input, '${n}_front.jpg'),
    ]);
    controller.addGlobalBack(p.join(input, '1_back.jpg'));
    final c4 = controller.project.cards[3];
    controller.setCardBack(c4.id, p.join(input, '4_back.jpg'));
    controller.selectPlan(1);

    await _capture(tester, controller, 'grid_editor_back');
  });

  testWidgets('card detail dialog render', (tester) async {
    final controller = ProjectController(const PnpProject(
      name: 'demo rejilla',
      mode: ProjectMode.grid,
      pageSize: SizeMm(210, 297),
    ));
    addTearDown(controller.dispose);
    controller.addCards([p.join(input, '1_front.jpg')]);
    controller.addGlobalBack(p.join(input, '1_back.jpg'));
    controller.addGlobalBack(p.join(input, '4_back.jpg'));
    final cardId = controller.project.cards.first.id;

    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        theme: desktopTheme(Brightness.light),
        home: Scaffold(
          body: CardDetailDialog(controller: controller, cardId: cardId),
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CardDetailDialog),
      matchesGoldenFile('goldens/card_detail_dialog.png'),
    );
  });

  testWidgets('freeform editor render', (tester) async {
    final controller = ProjectController(const PnpProject(
      name: 'demo libre',
      mode: ProjectMode.freeform,
      pageSize: SizeMm(210, 297),
    ));
    addTearDown(controller.dispose);
    // Real file IO must run inside runAsync in widget tests.
    await tester.runAsync(() async {
      await controller.addFreeItem(0, p.join(input, '1_front.jpg'));
      await controller.addFreeItem(0, p.join(input, '2_front.jpg'));
    });

    final items = controller.project.pages[0].items;
    controller.beginGesture();
    controller.moveItem(items[0].id, const PointMm(15, 25));
    controller.beginGesture();
    controller.moveItem(items[1].id, const PointMm(120, 150));
    controller.setItemBack(items[0].id, p.join(input, '1_back.jpg'));
    controller.selectItem(items[0].id);

    await _capture(tester, controller, 'freeform_editor');
  });

  testWidgets('freeform back page render', (tester) async {
    final controller = ProjectController(const PnpProject(
      name: 'demo libre',
      mode: ProjectMode.freeform,
      pageSize: SizeMm(210, 297),
    ));
    addTearDown(controller.dispose);
    await tester.runAsync(() async {
      await controller.addFreeItem(0, p.join(input, '1_front.jpg'));
    });
    final item = controller.project.pages[0].items.single;
    controller.beginGesture();
    controller.moveItem(item.id, const PointMm(15, 25));
    controller.setItemBack(item.id, p.join(input, '1_back.jpg'));
    controller.selectPlan(1);

    await _capture(tester, controller, 'freeform_editor_back');
  });
}
