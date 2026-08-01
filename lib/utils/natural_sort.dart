/// Compares two strings the way a person would order house/flat numbers:
/// numeric runs are compared by value ("2" < "10"), not lexicographically
/// ("10" < "2", which is what a plain string sort — and PocketBase's
/// `sort` param, which just does a database string ORDER BY — would give
/// you for text columns holding numbers). Non-numeric runs (e.g. block
/// letters) still compare as text. Handles mixed values like "H-2" vs
/// "H-10" correctly too.
int naturalCompare(String a, String b) {
  final aParts = _split(a);
  final bParts = _split(b);
  final len = aParts.length < bParts.length ? aParts.length : bParts.length;

  for (var i = 0; i < len; i++) {
    final aPart = aParts[i];
    final bPart = bParts[i];
    final aNum = int.tryParse(aPart);
    final bNum = int.tryParse(bPart);

    if (aNum != null && bNum != null) {
      final cmp = aNum.compareTo(bNum);
      if (cmp != 0) return cmp;
    } else {
      final cmp = aPart.compareTo(bPart);
      if (cmp != 0) return cmp;
    }
  }
  return aParts.length.compareTo(bParts.length);
}

final _splitPattern = RegExp(r'\d+|\D+');

List<String> _split(String value) =>
    _splitPattern.allMatches(value).map((m) => m.group(0)!).toList();