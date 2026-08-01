import 'package:intl/intl.dart';

/// PocketBase stores/compares date fields as plain strings in the format
/// `Y-m-d H:i:s.uZ` (e.g. "2026-07-01 00:00:00.000Z"). Create/update
/// bodies tolerate Dart's `DateTime.toIso8601String()` (with its 'T'
/// delimiter) because PocketBase casts/normalizes the value on save —
/// but *filter* comparisons do not: a 'T'-delimited value doesn't match
/// stored 'space'-delimited values, since the comparison is a plain
/// string comparison, not a real date comparison. Any date used inside
/// a filter string (not a create/update body) must go through this.
String pbFilterDate(DateTime dt) {
  final formatted = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(dt);
  return '${formatted}Z';
}