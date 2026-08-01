import 'package:intl/intl.dart';

/// Helpers for the simple "Jul 2026" style month labels used by
/// payments.month (spec §4 — "simple text, not a real date range").
class MonthUtils {
  MonthUtils._();

  static final DateFormat _format = DateFormat('MMM yyyy');

  static String currentMonthLabel() => _format.format(DateTime.now());

  static String labelFor(DateTime date) => _format.format(date);

  /// Returns the last [count] months (most recent first) as "Jul 2026"
  /// style labels, for the export screen's month picker.
  static List<String> recentMonths({int count = 12}) {
    final now = DateTime.now();
    return List.generate(count, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return _format.format(d);
    });
  }
}