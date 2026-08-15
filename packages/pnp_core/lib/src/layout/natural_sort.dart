/// Compares strings treating digit runs as numbers, so "card2" < "card10".
int compareNatural(String a, String b) {
  final digits = RegExp(r'\d+|\D+');
  final aParts = digits.allMatches(a).map((m) => m.group(0)!).toList();
  final bParts = digits.allMatches(b).map((m) => m.group(0)!).toList();

  for (var i = 0; i < aParts.length && i < bParts.length; i++) {
    final aPart = aParts[i];
    final bPart = bParts[i];
    final aNum = int.tryParse(aPart);
    final bNum = int.tryParse(bPart);

    int cmp;
    if (aNum != null && bNum != null) {
      cmp = aNum.compareTo(bNum);
    } else {
      cmp = aPart.compareTo(bPart);
    }
    if (cmp != 0) return cmp;
  }
  return aParts.length.compareTo(bParts.length);
}
