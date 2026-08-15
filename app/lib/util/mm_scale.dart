import 'dart:math';
import 'dart:ui';

import 'package:pnp_core/pnp_core.dart';

/// Scale (logical px per mm) that fits a page of [pageSize] inside
/// [viewport] with optional padding.
double fitPageScale(SizeMm pageSize, Size viewport, {double padding = 0}) {
  final availableWidth = max(1.0, viewport.width - 2 * padding);
  final availableHeight = max(1.0, viewport.height - 2 * padding);
  return min(availableWidth / pageSize.width, availableHeight / pageSize.height);
}

Rect rectMmToPx(RectMm rect, double scale) => Rect.fromLTWH(
    rect.x * scale, rect.y * scale, rect.width * scale, rect.height * scale);
