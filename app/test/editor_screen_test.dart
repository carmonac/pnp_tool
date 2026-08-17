import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pnp_core/pnp_core.dart';
import 'package:pnp_studio/screens/editor_screen.dart';
import 'package:pnp_studio/state/project_controller.dart';
import 'package:pnp_studio/strings.dart';
import 'package:pnp_studio/widgets/card_detail_dialog.dart';
import 'package:pnp_studio/widgets/image_drop_dialog.dart';
import 'package:pnp_studio/widgets/page_preview.dart';

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

    testWidgets('clicking cards selects them and shows the selection bar',
        (tester) async {
      controller.addGlobalBack(p.join(input, '4_back.jpg'));
      await _pumpEditor(tester, controller);

      await tester.tap(find.text('1_front.jpg'));
      await tester.pump();
      expect(controller.selectedCardIds.length, 1);
      expect(find.text('1 ${Strings.selectedCount}'), findsOneWidget);

      // Shift-click the second card extends the selection.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('2_front.jpg'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(controller.selectedCardIds.length, 2);
      expect(find.text('2 ${Strings.selectedCount}'), findsOneWidget);
    });

    testWidgets('bulk-assigning a global back updates every selected card',
        (tester) async {
      controller.addGlobalBack(p.join(input, '4_back.jpg'));
      final secondBackId = controller.project.globalBacks[1].id;
      await _pumpEditor(tester, controller);

      controller.selectAllCards();
      await tester.pump();

      controller.setCardsGlobalBack(
          controller.selectedCardIds, secondBackId);
      await tester.pump();

      for (final card in controller.project.cards) {
        expect(card.globalBackId, secondBackId);
        expect(controller.project.backRefFor(card), endsWith('4_back.jpg'));
      }
      // A single undo reverts the whole bulk assignment.
      controller.undo();
      for (final card in controller.project.cards) {
        expect(card.globalBackId, isNull);
      }
    });

    testWidgets('card detail modal opens from the context menu and assigns '
        'a global back via radio buttons', (tester) async {
      controller.addGlobalBack(p.join(input, '4_back.jpg'));
      final secondBackId = controller.project.globalBacks[1].id;
      await _pumpEditor(tester, controller);

      // Open the first card's context menu and choose Detalle.
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.detail));
      await tester.pumpAndSettle();

      // Modal shows the filename and the global-back picker (the card uses
      // a global back, so the checkbox starts checked).
      expect(find.byType(CardDetailDialog), findsOneWidget);
      expect(find.text(Strings.selectGlobalBackCheck), findsOneWidget);
      expect(find.text(Strings.addNewGlobalBack), findsOneWidget);

      // Pick the second global back via its radio row.
      await tester.tap(find.byWidgetPredicate((w) =>
          w is RadioListTile<String> && w.value == secondBackId));
      await tester.pump();
      expect(controller.project.cards.first.globalBackId, secondBackId);

      // Selecting "add new" reveals the drop zone.
      await tester.tap(find.text(Strings.addNewGlobalBack));
      await tester.pump();
      expect(find.byType(ImageDropZone), findsOneWidget);
    });

    testWidgets('clicking a card in the central preview opens its detail',
        (tester) async {
      await _pumpEditor(tester, controller);

      // Tap the center of the first card's cell inside the main preview
      // (the largest PagePreview on screen).
      final previews = find.byType(PagePreview);
      Rect biggest = Rect.zero;
      for (final element in previews.evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        if (rect.width > biggest.width) biggest = rect;
      }
      final plan = controller.plans.first;
      final scale = biggest.height / plan.pageSize.height;
      final cardRect = plan.images.first.rect;
      await tester.tapAt(Offset(
        biggest.left + (cardRect.left + cardRect.width / 2) * scale,
        biggest.top + (cardRect.top + cardRect.height / 2) * scale,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailDialog), findsOneWidget);
      expect(find.text('1_front.jpg'), findsWidgets);
    });

    testWidgets('drag-reordering a card does not throw', (tester) async {
      await _pumpEditor(tester, controller);

      final start = tester.getCenter(find.text('1_front.jpg'));
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 300));
      // Drag well past the second tile in small steps so the reorder logic
      // sees the displacement.
      for (var i = 1; i <= 10; i++) {
        await gesture.moveBy(const Offset(0, 12));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // The original bug: the dragged proxy threw (no Material/Provider in
      // the overlay). The reorder must complete without exceptions.
      expect(tester.takeException(), isNull);
      expect(controller.project.cards.first.frontRef,
          endsWith('2_front.jpg'));
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
