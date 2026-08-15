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

/// A shared back image that any number of cards can point to. Cards without
/// an explicit choice fall back to the project's first global back.
class GlobalBack {
  final String id;
  final String ref;

  const GlobalBack({required this.id, required this.ref});
}

class PnpProject {
  static const currentSchemaVersion = 2;

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
  final List<GlobalBack> globalBacks;

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
    this.globalBacks = const [],
    this.pages = const [FreePage()],
  });

  /// The back image to print for [card]: its own back if set, else its chosen
  /// global back, else the project's first global back, else none.
  String? backRefFor(CardItem card) {
    if (card.backRef != null) return card.backRef;
    if (card.globalBackId != null) {
      for (final back in globalBacks) {
        if (back.id == card.globalBackId) return back.ref;
      }
    }
    return globalBacks.isEmpty ? null : globalBacks.first.ref;
  }

  GlobalBack? globalBackById(String id) {
    for (final back in globalBacks) {
      if (back.id == id) return back;
    }
    return null;
  }

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
    List<GlobalBack>? globalBacks,
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
        globalBacks: globalBacks ?? this.globalBacks,
        pages: pages ?? this.pages,
      );

  static const _unset = Object();
}
