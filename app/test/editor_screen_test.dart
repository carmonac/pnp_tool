import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pnp_core/pnp_core.dart';
import 'package:pnp_studio/screens/editor_screen.dart';
import 'package:pnp_studio/state/project_controller.dart';
import 'package:pnp_studio/strings.dart';

String _repoRoot() {
  var dir = Directory.current;
  while (!Directory(p.join(dir.path, 'example', 'input')).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('example/input not found');
    dir = parent;
  }
  return dir.path;
}

Future<void> _pumpEditor(
    WidgetTester tester, ProjectController controller) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      MaterialApp(home: EditorScreen(controller: controller)));
  await tester.pump();
}

void main() {
  final input = p.join(_repoRoot(), 'example', 'input');

  group('grid editor', () {
    late ProjectController controller;

    setUp(() {
      controller = ProjectController(const PnpProject(
        name: 'demo',
        mode: ProjectMode.grid,
        pageSize: SizeMm(210, 297),
      ));
      controller.addCards([
        p.join(input, '1_front.jpg'),
        p.join(input, '2_front.jpg'),
      ]);
      controller.addGlobalBack(p.join(input, '1_back.jpg'));
    });

    tearDown(() => controller.dispose());

    testWidgets('shows cards, pages and global back', (tester) async {
      await _pumpEditor(tester, controller);

      expect(find.text('${Strings.cards} (2)'), findsOneWidget);
      expect(find.text('1_front.jpg'), findsOneWidget);
      expect(find.text('2_front.jpg'), findsOneWidget);
      expect(find.text(Strings.globalBacks), findsOneWidget);
      // The applied back's filename appears in the global-backs list and in
      // each card's subtitle.
      expect(find.text('1_back.jpg'), findsWidgets);
      // Thumbnail strip: front and back page labels.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('1b'), findsOneWidget);
    });

    testWidgets('selecting the back page thumbnail changes the main view',
        (tester) async {
      await _pumpEditor(tester, controller);

      expect(controller.selectedPlanIndex, 0);
      await tester.tap(find.text('1b'));
      await tester.pump();
      expect(controller.selectedPlanIndex, 1);
      expect(controller.selectedPlan!.isBackPage, isTrue);
    });

    testWidgets('undo/redo restore the card list', (tester) async {
      await _pumpEditor(tester, controller);

      expect(controller.project.cards.length, 2);
      controller.undo(); // undoes addGlobalBack
      controller.undo(); // undoes addCards
      await tester.pump();
      expect(controller.project.cards, isEmpty);
      expect(find.text('${Strings.cards} (0)'), findsOneWidget);

      controller.redo();
      await tester.pump();
      expect(controller.project.cards.length, 2);
    });

    testWidgets('empty project shows hint', (tester) async {
      final empty = ProjectController(const PnpProject(
        name: 'empty',
        mode: ProjectMode.grid,
        pageSize: SizeMm(210, 297),
      ));
      addTearDown(empty.dispose);
      await _pumpEditor(tester, empty);
      expect(find.text(Strings.emptyProjectHint), findsOneWidget);
    });
  });

  group('freeform editor', () {
    late ProjectController controller;

    setUp(() async {
      controller = ProjectController(const PnpProject(
        name: 'free',
        mode: ProjectMode.freeform,
        pageSize: SizeMm(210, 297),
      ));
      await controller.addFreeItem(0, p.join(input, '1_front.jpg'));
    });

    tearDown(() => controller.dispose());

    testWidgets('shows the item and read-only banner on the back page',
        (tester) async {
      await _pumpEditor(tester, controller);

      expect(find.text('${Strings.items} (1)'), findsOneWidget);
      expect(find.text(Strings.backPageReadOnly), findsNothing);

      await tester.tap(find.text('1b'));
      await tester.pump();
      expect(find.text(Strings.backPageReadOnly), findsOneWidget);
    });

    testWidgets('item back appears mirrored in the back plan',
        (tester) async {
      final item = controller.project.pages[0].items.single;
      controller.setItemBack(item.id, p.join(input, '1_back.jpg'));
      await _pumpEditor(tester, controller);

      final backPlan = controller.plans[1];
      final placed = backPlan.images.single;
      expect(placed.rect.x,
          closeTo(210 - item.rect.x - item.rect.width, 1e-9));
      expect(placed.rect.y, item.rect.y);
    });

    testWidgets('gesture move creates one undo step', (tester) async {
      await _pumpEditor(tester, controller);
      final item = controller.project.pages[0].items.single;
      final before = item.position;

      controller.beginGesture();
      controller.moveItem(item.id, PointMm(before.x + 3, before.y + 2));
      controller.moveItem(item.id, PointMm(before.x + 8, before.y + 5));
      await tester.pump();

      expect(controller.findItem(item.id)!.position,
          PointMm(before.x + 8, before.y + 5));
      controller.undo();
      expect(controller.findItem(item.id)!.position, before);
    });
  });
}
