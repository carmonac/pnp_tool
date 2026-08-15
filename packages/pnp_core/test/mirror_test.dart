import 'package:pnp_core/pnp_core.dart';
import 'package:test/test.dart';

void main() {
  test('mirrorX is an involution', () {
    const pageWidth = 210.0;
    for (final x in [0.0, 5.76, 100.0, 146.5]) {
      final mirrored = mirrorX(x, 63.5, pageWidth);
      expect(mirrorX(mirrored, 63.5, pageWidth), closeTo(x, 1e-9));
    }
  });

  test('mirrorX maps left edge to right edge', () {
    // Item at x=10, width 50 on a 210 page: right edge at 60 from the left
    // means the mirrored left edge is 60 from the right: 150.
    expect(mirrorX(10, 50, 210), 150);
  });

  test('mirrorRect keeps y and size', () {
    const rect = RectMm(20, 30, 40, 50);
    final mirrored = mirrorRect(rect, 210);
    expect(mirrored.y, rect.y);
    expect(mirrored.width, rect.width);
    expect(mirrored.height, rect.height);
    expect(mirrored.x, 210 - 20 - 40);
  });

  test('centered element mirrors onto itself', () {
    const rect = RectMm(80, 0, 50, 10); // centered on a 210 page
    final mirrored = mirrorRect(rect, 210);
    expect(mirrored.x, closeTo(rect.x, 1e-9));
  });
}
