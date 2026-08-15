/// A card in a grid-mode project.
class CardItem {
  final String id;
  final String frontRef;

  /// Back image ref. When null the project's global back (if any) is used.
  final String? backRef;

  /// Number of copies of this card to emit.
  final int count;

  const CardItem({
    required this.id,
    required this.frontRef,
    this.backRef,
    this.count = 1,
  });

  CardItem copyWith({
    String? frontRef,
    Object? backRef = _unset,
    int? count,
  }) =>
      CardItem(
        id: id,
        frontRef: frontRef ?? this.frontRef,
        backRef: backRef == _unset ? this.backRef : backRef as String?,
        count: count ?? this.count,
      );

  static const _unset = Object();
}
