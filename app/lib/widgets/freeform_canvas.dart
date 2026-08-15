import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pnp_core/pnp_core.dart';
import 'package:provider/provider.dart';

import '../state/project_controller.dart';
import '../strings.dart';
import '../util/mm_scale.dart';
import 'page_preview.dart';

const _snapThresholdMm = 1.5;
const _minItemSizeMm = 5.0;
const _handleSizePx = 10.0;

/// Editable canvas for freeform front pages. Back pages render read-only:
/// their content is always derived from the fronts, which keeps the duplex
/// alignment invariant unbreakable.
class FreeformCanvas extends StatefulWidget {
  const FreeformCanvas({super.key});

  @override
  State<FreeformCanvas> createState() => _FreeformCanvasState();
}

class _FreeformCanvasState extends State<FreeformCanvas> {
  final _focusNode = FocusNode();

  // Active snap guides (page coordinates, mm) shown during a drag.
  List<double> _guideXs = [];
  List<double> _guideYs = [];

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final plan = controller.selectedPlan;
    if (plan == null) return const SizedBox.shrink();

    if (plan.isBackPage) {
      return Column(
        children: [
          MaterialBanner(
            content: const Text(Strings.backPageReadOnly),
            leading: const Icon(Icons.lock_outline),
            actions: const [SizedBox.shrink()],
          ),
          Expanded(child: _readOnlyPreview(controller, plan)),
        ],
      );
    }

    final sheetIndex = controller.selectedSheetIndex;
    final items = sheetIndex < controller.project.pages.length
        ? controller.project.pages[sheetIndex].items
        : const <FreeItem>[];

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) => _onKey(controller, event),
      child: GestureDetector(
        onTap: () {
          _focusNode.requestFocus();
          controller.selectItem(null);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final page = controller.project.pageSize;
            final scale = fitPageScale(
                page, constraints.biggest, padding: 24);
            final pageSizePx = Size(page.width * scale, page.height * scale);
            final origin = Offset(
              (constraints.maxWidth - pageSizePx.width) / 2,
              (constraints.maxHeight - pageSizePx.height) / 2,
            );

            return Stack(
              children: [
                Positioned(
                  left: origin.dx,
                  top: origin.dy,
                  width: pageSizePx.width,
                  height: pageSizePx.height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: PagePreview(
                      plan: plan,
                      fitMode: controller.project.fitMode,
                      imageCache: context.read<PreviewImageCache>(),
                      highlightedImageId: controller.selectedItemId,
                      imageItemIds: [for (final item in items) item.id],
                    ),
                  ),
                ),
                // Snap guides.
                for (final x in _guideXs)
                  Positioned(
                    left: origin.dx + x * scale,
                    top: origin.dy,
                    width: 1,
                    height: pageSizePx.height,
                    child: const ColoredBox(color: Colors.pinkAccent),
                  ),
                for (final y in _guideYs)
                  Positioned(
                    left: origin.dx,
                    top: origin.dy + y * scale,
                    width: pageSizePx.width,
                    height: 1,
                    child: const ColoredBox(color: Colors.pinkAccent),
                  ),
                // Gesture layer per item.
                for (final item in items)
                  _ItemGestureLayer(
                    item: item,
                    origin: origin,
                    scale: scale,
                    focusNode: _focusNode,
                    onGuides: (xs, ys) =>
                        setState(() { _guideXs = xs; _guideYs = ys; }),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _readOnlyPreview(ProjectController controller, PagePlan plan) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
              ),
            ],
          ),
          child: PagePreview(
            plan: plan,
            fitMode: controller.project.fitMode,
            imageCache: context.read<PreviewImageCache>(),
          ),
        ),
      ),
    );
  }

  KeyEventResult _onKey(ProjectController controller, KeyEvent event) {
    final selected = controller.selectedItemId;
    if (selected == null || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final item = controller.findItem(selected);
    if (item == null) return KeyEventResult.ignored;

    final step = HardwareKeyboard.instance.isShiftPressed ? 5.0 : 0.5;
    var dx = 0.0, dy = 0.0;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        dx = -step;
      case LogicalKeyboardKey.arrowRight:
        dx = step;
      case LogicalKeyboardKey.arrowUp:
        dy = -step;
      case LogicalKeyboardKey.arrowDown:
        dy = step;
      case LogicalKeyboardKey.delete || LogicalKeyboardKey.backspace:
        controller.removeItem(selected);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }

    controller.beginGesture();
    controller.moveItem(
        selected, PointMm(item.position.x + dx, item.position.y + dy));
    return KeyEventResult.handled;
  }
}

class _ItemGestureLayer extends StatefulWidget {
  final FreeItem item;
  final Offset origin;
  final double scale;
  final FocusNode focusNode;
  final void Function(List<double> xs, List<double> ys) onGuides;

  const _ItemGestureLayer({
    required this.item,
    required this.origin,
    required this.scale,
    required this.focusNode,
    required this.onGuides,
  });

  @override
  State<_ItemGestureLayer> createState() => _ItemGestureLayerState();
}

class _ItemGestureLayerState extends State<_ItemGestureLayer> {
  PointMm? _dragStartPosition;
  Offset? _panStartGlobal;
  SizeMm? _resizeStartSize;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ProjectController>();
    final item = widget.item;
    final selected =
        context.select<ProjectController, bool>(
            (c) => c.selectedItemId == item.id);
    final rect = Rect.fromLTWH(
      widget.origin.dx + item.position.x * widget.scale,
      widget.origin.dy + item.position.y * widget.scale,
      item.size.width * widget.scale,
      item.size.height * widget.scale,
    );

    return Positioned.fromRect(
      rect: rect.inflate(_handleSizePx),
      child: Stack(
        children: [
          // Body: select + drag.
          Positioned.fill(
            left: _handleSizePx,
            top: _handleSizePx,
            right: _handleSizePx,
            bottom: _handleSizePx,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) {
                widget.focusNode.requestFocus();
                controller.selectItem(item.id);
              },
              onPanStart: (details) {
                widget.focusNode.requestFocus();
                controller.selectItem(item.id);
                controller.beginGesture();
                _dragStartPosition = item.position;
                _panStartGlobal = details.globalPosition;
              },
              onPanUpdate: (details) => _onDrag(controller, details),
              onPanEnd: (_) {
                _dragStartPosition = null;
                widget.onGuides(const [], const []);
              },
              child: MouseRegion(cursor: SystemMouseCursors.move),
            ),
          ),
          // Corner resize handles when selected.
          if (selected)
            for (final alignment in const [
              Alignment.topLeft,
              Alignment.topRight,
              Alignment.bottomLeft,
              Alignment.bottomRight,
            ])
              Align(
                alignment: alignment,
                child: GestureDetector(
                  onPanStart: (details) {
                    controller.beginGesture();
                    _dragStartPosition = item.position;
                    _resizeStartSize = item.size;
                    _panStartGlobal = details.globalPosition;
                  },
                  onPanUpdate: (details) =>
                      _onResize(controller, details, alignment),
                  onPanEnd: (_) {
                    _dragStartPosition = null;
                    _resizeStartSize = null;
                  },
                  child: MouseRegion(
                    cursor: alignment == Alignment.topLeft ||
                            alignment == Alignment.bottomRight
                        ? SystemMouseCursors.resizeUpLeftDownRight
                        : SystemMouseCursors.resizeUpRightDownLeft,
                    child: Container(
                      width: _handleSizePx,
                      height: _handleSizePx,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.blueAccent),
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  void _onDrag(ProjectController controller, DragUpdateDetails details) {
    final start = _dragStartPosition;
    final panStart = _panStartGlobal;
    if (start == null || panStart == null) return;

    final deltaPx = details.globalPosition - panStart;
    var x = start.x + deltaPx.dx / widget.scale;
    var y = start.y + deltaPx.dy / widget.scale;

    final (snappedX, snappedY, guideXs, guideYs) =
        _snap(controller, x, y);
    controller.moveItem(widget.item.id, PointMm(snappedX, snappedY));
    widget.onGuides(guideXs, guideYs);
  }

  /// Snaps the candidate position against page edges, page center and other
  /// items' edges. Returns the snapped position plus active guide lines.
  (double, double, List<double>, List<double>) _snap(
      ProjectController controller, double x, double y) {
    final page = controller.project.pageSize;
    final item = widget.item;
    final sheetIndex = controller.selectedSheetIndex;
    final others = controller.project.pages[sheetIndex].items
        .where((other) => other.id != item.id);

    final xTargets = <double>[
      0,
      (page.width - item.size.width) / 2,
      page.width - item.size.width,
      for (final other in others) ...[
        other.rect.left,
        other.rect.right,
        other.rect.left - item.size.width,
        other.rect.right - item.size.width,
      ],
    ];
    final yTargets = <double>[
      0,
      (page.height - item.size.height) / 2,
      page.height - item.size.height,
      for (final other in others) ...[
        other.rect.top,
        other.rect.bottom,
        other.rect.top - item.size.height,
        other.rect.bottom - item.size.height,
      ],
    ];

    final guideXs = <double>[];
    final guideYs = <double>[];

    for (final target in xTargets) {
      if ((x - target).abs() <= _snapThresholdMm) {
        x = target;
        guideXs.addAll([target, target + item.size.width]);
        break;
      }
    }
    for (final target in yTargets) {
      if ((y - target).abs() <= _snapThresholdMm) {
        y = target;
        guideYs.addAll([target, target + item.size.height]);
        break;
      }
    }

    return (x, y, guideXs, guideYs);
  }

  void _onResize(ProjectController controller, DragUpdateDetails details,
      Alignment corner) {
    final startPos = _dragStartPosition;
    final startSize = _resizeStartSize;
    final panStart = _panStartGlobal;
    if (startPos == null || startSize == null || panStart == null) return;

    final deltaPx = details.globalPosition - panStart;
    final dxMm = deltaPx.dx / widget.scale;
    final dyMm = deltaPx.dy / widget.scale;
    final keepAspect = !HardwareKeyboard.instance.isShiftPressed;

    final left = corner.x < 0;
    final top = corner.y < 0;

    var width = startSize.width + (left ? -dxMm : dxMm);
    var height = startSize.height + (top ? -dyMm : dyMm);

    if (keepAspect) {
      final aspect = startSize.width / startSize.height;
      // Follow the dominant axis of the gesture.
      if ((width - startSize.width).abs() >=
          (height - startSize.height).abs()) {
        height = width / aspect;
      } else {
        width = height * aspect;
      }
    }

    width = max(width, _minItemSizeMm);
    height = max(height, _minItemSizeMm);

    final x = left ? startPos.x + startSize.width - width : startPos.x;
    final y = top ? startPos.y + startSize.height - height : startPos.y;

    controller.resizeItem(
        widget.item.id, PointMm(x, y), SizeMm(width, height));
  }
}
