import 'geometry.dart';

/// Standard page sizes. `custom` has no fixed size; the project stores it.
enum PagePreset {
  a4('A4', SizeMm(210, 297)),
  a3('A3', SizeMm(297, 420)),
  a5('A5', SizeMm(148, 210)),
  letter('Letter', SizeMm(215.9, 279.4)),
  legal('Legal', SizeMm(215.9, 355.6)),
  custom('Custom', null);

  final String label;
  final SizeMm? size;

  const PagePreset(this.label, this.size);

  static PagePreset? fromName(String name) =>
      values.where((p) => p.name == name).firstOrNull;

  /// Finds the preset matching [size], or `custom` if none matches.
  static PagePreset match(SizeMm size) =>
      values.where((p) => p.size == size).firstOrNull ?? custom;
}

/// Standard card sizes. `custom` has no fixed size; the project stores it.
enum CardPreset {
  poker('Poker (63.5 x 88.9)', SizeMm(63.5, 88.9)),
  bridge('Bridge (57.15 x 88.9)', SizeMm(57.15, 88.9)),
  tarot('Tarot (70 x 120)', SizeMm(70, 120)),
  miniUs('Mini US (41 x 63)', SizeMm(41, 63)),
  miniEuro('Mini Euro (44 x 68)', SizeMm(44, 68)),
  stdEuro('Standard Euro (59 x 92)', SizeMm(59, 92)),
  square('Square (70 x 70)', SizeMm(70, 70)),
  custom('Custom', null);

  final String label;
  final SizeMm? size;

  const CardPreset(this.label, this.size);

  static CardPreset? fromName(String name) =>
      values.where((p) => p.name == name).firstOrNull;

  /// Finds the preset matching [size], or `custom` if none matches.
  static CardPreset match(SizeMm size) =>
      values.where((p) => p.size == size).firstOrNull ?? custom;
}
