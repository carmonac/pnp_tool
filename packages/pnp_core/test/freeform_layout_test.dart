import 'package:pnp_core/pnp_core.dart';
import 'package:test/test.dart';

void main() {
  PnpProject freeform(List<FreePage> pages) => PnpProject(
        name: 'test',
        mode: ProjectMode.freeform,
        pageSize: const SizeMm(210, 297),
        pages: pages,
      );

  test('back page mirrors item positions horizontally', () {
    final plans = planFreeform(freeform([
      const FreePage(items: [
        FreeItem(
          id: 'a',
          frontRef: 'a.png',
          backRef: 'a_back.png',
          position: PointMm(10, 20),
          size: SizeMm(50, 70),
        ),
      ]),
    ]));

    expect(plans.length, 2);
    final back = plans[1].images.single;
    expect(back.imageRef, 'a_back.png');
    expect(back.rect.x, closeTo(210 - 10 - 50, 1e-9));
    expect(back.rect.y, 20);
    expect(back.rect.width, 50);
    expect(back.rect.height, 70);
  });

  test('items without a back are omitted from the back page', () {
    final plans = planFreeform(freeform([
      const FreePage(items: [
        FreeItem(
            id: 'a',
            frontRef: 'a.png',
            position: PointMm(0, 0),
            size: SizeMm(30, 30)),
        FreeItem(
            id: 'b',
            frontRef: 'b.png',
            backRef: 'b_back.png',
            position: PointMm(100, 100),
            size: SizeMm(30, 30)),
      ]),
    ]));

    expect(plans[0].images.length, 2);
    expect(plans[1].images.length, 1);
    expect(plans[1].images.single.imageRef, 'b_back.png');
  });

  test('back page is emitted even when no item has a back', () {
    final plans = planFreeform(freeform([
      const FreePage(items: [
        FreeItem(
            id: 'a',
            frontRef: 'a.png',
            position: PointMm(0, 0),
            size: SizeMm(30, 30)),
      ]),
    ]));
    expect(plans.length, 2);
    expect(plans[1].isBackPage, isTrue);
    expect(plans[1].images, isEmpty);
  });

  test('multiple pages keep duplex pairing and labels', () {
    final plans = planFreeform(freeform([
      const FreePage(),
      const FreePage(),
    ]));
    expect(plans.map((p) => p.label), ['1', '1b', '2', '2b']);
    expect(plans.map((p) => p.sheetNumber), [1, 1, 2, 2]);
  });

  test('crop marks surround each item and mirror on the back page', () {
    final plans = planFreeform(freeform([
      const FreePage(items: [
        FreeItem(
          id: 'a',
          frontRef: 'a.png',
          backRef: 'a_back.png',
          position: PointMm(50, 50),
          size: SizeMm(40, 60),
        ),
      ]),
    ]));
    // 4 corners x 2 ticks each.
    expect(plans[0].cutLines.length, 8);
    expect(plans[1].cutLines.length, 8);

    for (final mark in plans[0].cutLines) {
      final mirrored = mirrorRect(mark, 210);
      expect(
        plans[1].cutLines.any((l) =>
            (l.x - mirrored.x).abs() < 1e-6 &&
            (l.y - mirrored.y).abs() < 1e-6 &&
            (l.width - mirrored.width).abs() < 1e-6 &&
            (l.height - mirrored.height).abs() < 1e-6),
        isTrue,
        reason: 'No mirrored mark for $mark',
      );
    }
  });
}
