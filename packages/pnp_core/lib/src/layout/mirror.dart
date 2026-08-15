import '../models/geometry.dart';

/// Mirrors an x coordinate for long-edge duplex printing: an element of width
/// [width] whose left edge is at [x] on the front page must sit at the
/// returned x on the back page for both to align when the sheet is flipped.
double mirrorX(double x, double width, double pageWidth) =>
    pageWidth - x - width;

/// Mirrors a rectangle horizontally on a page (y is unchanged).
RectMm mirrorRect(RectMm rect, double pageWidth) => RectMm(
    mirrorX(rect.x, rect.width, pageWidth), rect.y, rect.width, rect.height);
