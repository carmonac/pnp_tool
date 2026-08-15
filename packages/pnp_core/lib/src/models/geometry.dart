/// Immutable geometry value types in millimeters.
library;

class SizeMm {
  final double width;
  final double height;

  const SizeMm(this.width, this.height);

  SizeMm get flipped => SizeMm(height, width);

  @override
  bool operator ==(Object other) =>
      other is SizeMm && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'SizeMm($width x $height)';
}

class PointMm {
  final double x;
  final double y;

  const PointMm(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is PointMm && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'PointMm($x, $y)';
}

class RectMm {
  final double x;
  final double y;
  final double width;
  final double height;

  const RectMm(this.x, this.y, this.width, this.height);

  double get left => x;
  double get top => y;
  double get right => x + width;
  double get bottom => y + height;
  PointMm get position => PointMm(x, y);
  SizeMm get size => SizeMm(width, height);

  RectMm inflate(double amount) => RectMm(
      x - amount, y - amount, width + 2 * amount, height + 2 * amount);

  @override
  bool operator ==(Object other) =>
      other is RectMm &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'RectMm($x, $y, $width x $height)';
}
