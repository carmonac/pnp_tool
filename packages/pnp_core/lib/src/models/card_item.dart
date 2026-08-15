/// A card in a grid-mode project.
class CardItem {
  final String id;
  final String frontRef;

  /// Back image ref. When null, [globalBackId] (or the project's first
  /// global back) decides the printed back.
  final String? backRef;

  /// Id of the chosen global back, used when [backRef] is null. When this is
  /// also null the project's first global back (if any) applies.
  final String? globalBackId;

  /// Number of copies of this card to emit.
  final int count;

  const CardItem({
    required this.id,
    required this.frontRef,
    this.backRef,
    this.globalBackId,
    this.count = 1,
  });

  CardItem copyWith({
    String? frontRef,
    Object? backRef = _unset,
    Object? globalBackId = _unset,
    int? count,
  }) =>
      CardItem(
        id: id,
        frontRef: frontRef ?? this.frontRef,
        backRef: backRef == _unset ? this.backRef : backRef as String?,
        globalBackId: globalBackId == _unset
            ? this.globalBackId
            : globalBackId as String?,
        count: count ?? this.count,
      );

  static const _unset = Object();
}
