import 'card_item.dart';
import 'free_item.dart';
import 'geometry.dart';

enum ProjectMode { grid, freeform }

/// How a card image is fitted into its target rectangle.
enum FitMode {
  /// Center-crop to fill the rectangle (default).
  cover,

  /// Letterbox inside the rectangle, padding with transparency.
  contain,

  /// Distort to fill the rectangle.
  stretch,
}

class PnpProject {
  static const currentSchemaVersion = 1;

  final String name;
  final ProjectMode mode;
  final SizeMm pageSize;
  final double bleedMm;
  final bool drawCutLines;
  final bool drawCalibration;

  /// JPEG quality (1-100) for embedded opaque images; null keeps lossless PNG.
  final int? jpegQuality;
  final FitMode fitMode;

  // Grid mode.
  final SizeMm cardSize;
  final double spacingMm;
  final double minMarginMm;
  final List<CardItem> cards;
  final String? globalBackRef;

  // Freeform mode.
  final List<FreePage> pages;

  const PnpProject({
    required this.name,
    required this.mode,
    required this.pageSize,
    this.bleedMm = 1.0,
    this.drawCutLines = true,
    this.drawCalibration = true,
    this.jpegQuality = 90,
    this.fitMode = FitMode.cover,
    this.cardSize = const SizeMm(63.5, 88.9),
    this.spacingMm = 4.0,
    this.minMarginMm = 5.0,
    this.cards = const [],
    this.globalBackRef,
    this.pages = const [FreePage()],
  });

  PnpProject copyWith({
    String? name,
    SizeMm? pageSize,
    double? bleedMm,
    bool? drawCutLines,
    bool? drawCalibration,
    Object? jpegQuality = _unset,
    FitMode? fitMode,
    SizeMm? cardSize,
    double? spacingMm,
    double? minMarginMm,
    List<CardItem>? cards,
    Object? globalBackRef = _unset,
    List<FreePage>? pages,
  }) =>
      PnpProject(
        name: name ?? this.name,
        mode: mode,
        pageSize: pageSize ?? this.pageSize,
        bleedMm: bleedMm ?? this.bleedMm,
        drawCutLines: drawCutLines ?? this.drawCutLines,
        drawCalibration: drawCalibration ?? this.drawCalibration,
        jpegQuality:
            jpegQuality == _unset ? this.jpegQuality : jpegQuality as int?,
        fitMode: fitMode ?? this.fitMode,
        cardSize: cardSize ?? this.cardSize,
        spacingMm: spacingMm ?? this.spacingMm,
        minMarginMm: minMarginMm ?? this.minMarginMm,
        cards: cards ?? this.cards,
        globalBackRef: globalBackRef == _unset
            ? this.globalBackRef
            : globalBackRef as String?,
        pages: pages ?? this.pages,
      );

  static const _unset = Object();
}
