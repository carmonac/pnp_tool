import '../models/geometry.dart';
import '../models/project.dart';
import 'mirror.dart';
import 'page_plan.dart';

const _cutLineThicknessMm = 0.35;

/// Describes the grid that fits a project's page: column/row counts and the
/// centered margins.
class GridGeometry {
  final int columns;
  final int rows;
  final double marginLeft;
  final double marginTop;

  const GridGeometry({
    required this.columns,
    required this.rows,
    required this.marginLeft,
    required this.marginTop,
  });

  int get cardsPerPage => columns * rows;
}

/// Computes how many cards fit on the page and centers the resulting block,
/// honoring the minimum margin on every edge.
GridGeometry computeGridGeometry(PnpProject project) {
  final page = project.pageSize;
  final card = project.cardSize;
  final spacing = project.spacingMm;
  final minMargin = project.minMarginMm;

  int fitCount(double available, double item) {
    if (item <= 0) return 0;
    return ((available + spacing) / (item + spacing)).floor();
  }

  final columns = fitCount(page.width - 2 * minMargin, card.width);
  final rows = fitCount(page.height - 2 * minMargin, card.height);
  if (columns < 1 || rows < 1) {
    throw ArgumentError(
        'Card size ${card.width}x${card.height}mm does not fit on page '
        '${page.width}x${page.height}mm with a ${minMargin}mm margin.');
  }

  final blockWidth = columns * card.width + (columns - 1) * spacing;
  final blockHeight = rows * card.height + (rows - 1) * spacing;

  return GridGeometry(
    columns: columns,
    rows: rows,
    marginLeft: (page.width - blockWidth) / 2,
    marginTop: (page.height - blockHeight) / 2,
  );
}

/// Lays out a grid-mode project as alternating front/back [PagePlan]s.
List<PagePlan> planGrid(PnpProject project) {
  assert(project.mode == ProjectMode.grid);

  final page = project.pageSize;
  final card = project.cardSize;
  final spacing = project.spacingMm;
  final grid = computeGridGeometry(project);

  // Expand copy counts into individual occurrences.
  final occurrences = [
    for (final item in project.cards)
      for (var i = 0; i < item.count; i++) item,
  ];

  final cutLines =
      project.drawCutLines ? _gridCutLines(project, grid) : const <RectMm>[];

  final plans = <PagePlan>[];
  final perPage = grid.cardsPerPage;
  final totalSheets = (occurrences.length / perPage).ceil();

  for (var sheet = 0; sheet < totalSheets; sheet++) {
    final pageCards =
        occurrences.skip(sheet * perPage).take(perPage).toList();

    RectMm cellRect(int index) {
      final row = index ~/ grid.columns;
      final col = index % grid.columns;
      return RectMm(
        grid.marginLeft + col * (card.width + spacing),
        grid.marginTop + row * (card.height + spacing),
        card.width,
        card.height,
      );
    }

    plans.add(PagePlan(
      pageSize: page,
      label: '${sheet + 1}',
      isBackPage: false,
      sheetNumber: sheet + 1,
      cutLines: cutLines,
      images: [
        for (var i = 0; i < pageCards.length; i++)
          PlacedImage(
            imageRef: pageCards[i].frontRef,
            rect: cellRect(i),
            isBack: false,
          ),
      ],
    ));

    plans.add(PagePlan(
      pageSize: page,
      label: '${sheet + 1}b',
      isBackPage: true,
      sheetNumber: sheet + 1,
      // Centered margins make the cut-line set mirror-symmetric, so the same
      // lines are valid on the back page.
      cutLines: cutLines,
      images: [
        for (var i = 0; i < pageCards.length; i++)
          if ((pageCards[i].backRef ?? project.globalBackRef) != null)
            PlacedImage(
              imageRef: (pageCards[i].backRef ?? project.globalBackRef)!,
              rect: mirrorRect(cellRect(i), page.width),
              isBack: true,
            ),
      ],
    ));
  }

  return plans;
}

/// Cut marks in the page margins: one mark per card edge, centered on the
/// edge coordinate, running from the paper edge to the card block.
List<RectMm> _gridCutLines(PnpProject project, GridGeometry grid) {
  final page = project.pageSize;
  final card = project.cardSize;
  final spacing = project.spacingMm;
  const t = _cutLineThicknessMm;

  final lines = <RectMm>[];

  final marginRight = page.width -
      (grid.marginLeft +
          grid.columns * card.width +
          (grid.columns - 1) * spacing);
  final marginBottom = page.height -
      (grid.marginTop + grid.rows * card.height + (grid.rows - 1) * spacing);

  // Vertical marks at each card's left/right edge, in the top/bottom margins.
  for (var col = 0; col < grid.columns; col++) {
    final left = grid.marginLeft + col * (card.width + spacing);
    for (final x in [left, left + card.width]) {
      lines.add(RectMm(x - t / 2, 0, t, grid.marginTop));
      lines.add(
          RectMm(x - t / 2, page.height - marginBottom, t, marginBottom));
    }
  }

  // Horizontal marks at each card's top/bottom edge, in the side margins.
  for (var row = 0; row < grid.rows; row++) {
    final top = grid.marginTop + row * (card.height + spacing);
    for (final y in [top, top + card.height]) {
      lines.add(RectMm(0, y - t / 2, grid.marginLeft, t));
      lines.add(RectMm(page.width - marginRight, y - t / 2, marginRight, t));
    }
  }

  return lines;
}
