import 'package:pnp_core/pnp_core.dart';
import 'package:test/test.dart';

PnpProject gridProject({
  SizeMm pageSize = const SizeMm(210, 297),
  SizeMm cardSize = const SizeMm(63.5, 88.9),
  List<CardItem> cards = const [],
  String? globalBackRef,
}) =>
    PnpProject(
      name: 'test',
      mode: ProjectMode.grid,
      pageSize: pageSize,
      cardSize: cardSize,
      cards: cards,
      globalBackRef: globalBackRef,
    );

List<CardItem> makeCards(int n, {String? back}) => [
      for (var i = 0; i < n; i++)
        CardItem(id: 'c$i', frontRef: 'front_$i.png', backRef: back),
    ];

void main() {
  group('computeGridGeometry', () {
    test('A4 + poker fits 3x3 with no page overflow', () {
      final grid = computeGridGeometry(gridProject());
      expect(grid.columns, 3);
      expect(grid.rows, 3);

      final rightEdge = grid.marginLeft + 3 * 63.5 + 2 * 4.0;
      expect(rightEdge, lessThanOrEqualTo(210 - 5.0));
      expect(grid.marginLeft, greaterThanOrEqualTo(5.0));
    });

    test('grid is centered', () {
      final grid = computeGridGeometry(gridProject());
      final blockWidth = 3 * 63.5 + 2 * 4.0;
      expect(grid.marginLeft, closeTo((210 - blockWidth) / 2, 1e-9));
      final blockHeight = 3 * 88.9 + 2 * 4.0;
      expect(grid.marginTop, closeTo((297 - blockHeight) / 2, 1e-9));
    });

    test('Letter + poker fits 3x2', () {
      final grid = computeGridGeometry(
          gridProject(pageSize: const SizeMm(215.9, 279.4)));
      expect(grid.columns, 3);
      expect(grid.rows, 2);
    });

    test('A3 + poker fits 4x4', () {
      final grid =
          computeGridGeometry(gridProject(pageSize: const SizeMm(297, 420)));
      expect(grid.columns, 4);
      expect(grid.rows, 4);
    });

    test('A4 + tarot fits 2x2', () {
      final grid =
          computeGridGeometry(gridProject(cardSize: const SizeMm(70, 120)));
      expect(grid.columns, 2);
      expect(grid.rows, 2);
    });

    test('card larger than page throws', () {
      expect(() => computeGridGeometry(gridProject(cardSize: const SizeMm(300, 300))),
          throwsArgumentError);
    });
  });

  group('planGrid', () {
    test('emits front/back page pairs', () {
      final plans = planGrid(gridProject(
          cards: makeCards(10, back: 'back.png')));
      // 10 cards, 9 per page -> 2 sheets -> 4 pages.
      expect(plans.length, 4);
      expect(plans.map((p) => p.label), ['1', '1b', '2', '2b']);
      expect(plans.map((p) => p.isBackPage), [false, true, false, true]);
      expect(plans[0].images.length, 9);
      expect(plans[2].images.length, 1);
    });

    test('count expands into copies', () {
      final plans = planGrid(gridProject(cards: [
        const CardItem(id: 'a', frontRef: 'a.png', backRef: 'b.png', count: 3),
      ]));
      expect(plans[0].images.length, 3);
      expect(plans[0].images.every((i) => i.imageRef == 'a.png'), isTrue);
    });

    test('back page mirrors columns', () {
      final plans =
          planGrid(gridProject(cards: makeCards(3, back: 'back.png')));
      final front = plans[0].images;
      final back = plans[1].images;

      // Front left card's back must be at the mirrored x; same y.
      for (var i = 0; i < 3; i++) {
        expect(back[i].rect.x,
            closeTo(210 - front[i].rect.x - front[i].rect.width, 1e-9));
        expect(back[i].rect.y, front[i].rect.y);
      }
      // With 3 columns, back column order is reversed: back of col 0 at col 2.
      expect(back[0].rect.x, closeTo(front[2].rect.x, 1e-9));
      expect(back[2].rect.x, closeTo(front[0].rect.x, 1e-9));
    });

    test('per-card back wins over global back', () {
      final plans = planGrid(gridProject(
        cards: [
          const CardItem(id: 'a', frontRef: 'a.png', backRef: 'own.png'),
          const CardItem(id: 'b', frontRef: 'b.png'),
        ],
        globalBackRef: 'global.png',
      ));
      expect(plans[1].images.map((i) => i.imageRef), ['own.png', 'global.png']);
    });

    test('cards without any back are skipped on the back page', () {
      final plans = planGrid(gridProject(cards: makeCards(2)));
      expect(plans[1].images, isEmpty);
      expect(plans[1].isBackPage, isTrue);
    });

    test('cut line set is mirror-symmetric so it works on back pages', () {
      final plans =
          planGrid(gridProject(cards: makeCards(1, back: 'back.png')));
      final lines = plans[0].cutLines;
      expect(lines, isNotEmpty);
      for (final line in lines) {
        final mirrored = mirrorRect(line, 210);
        expect(
          lines.any((l) =>
              (l.x - mirrored.x).abs() < 1e-6 &&
              (l.y - mirrored.y).abs() < 1e-6 &&
              (l.width - mirrored.width).abs() < 1e-6 &&
              (l.height - mirrored.height).abs() < 1e-6),
          isTrue,
          reason: 'No mirror twin for $line',
        );
      }
    });

    test('vertical cut mark count matches columns', () {
      final plans =
          planGrid(gridProject(cards: makeCards(1, back: 'back.png')));
      final vertical =
          plans[0].cutLines.where((l) => l.height > l.width).length;
      // 2 edges per column, marks at top and bottom margins.
      expect(vertical, 3 * 2 * 2);
    });
  });
}
