import 'geometry.dart';

/// An arbitrarily sized and positioned image in a freeform-mode project.
class FreeItem {
  final String id;
  final String frontRef;
  final String? backRef;

  /// Top-left corner on the page, in mm.
  final PointMm position;
  final SizeMm size;

  const FreeItem({
    required this.id,
    required this.frontRef,
    this.backRef,
    required this.position,
    required this.size,
  });

  RectMm get rect => RectMm(position.x, position.y, size.width, size.height);

  FreeItem copyWith({
    String? frontRef,
    Object? backRef = _unset,
    PointMm? position,
    SizeMm? size,
  }) =>
      FreeItem(
        id: id,
        frontRef: frontRef ?? this.frontRef,
        backRef: backRef == _unset ? this.backRef : backRef as String?,
        position: position ?? this.position,
        size: size ?? this.size,
      );

  static const _unset = Object();
}

/// One user-authored page of a freeform project (front side).
class FreePage {
  final List<FreeItem> items;

  const FreePage({this.items = const []});

  FreePage copyWith({List<FreeItem>? items}) =>
      FreePage(items: items ?? this.items);
}
