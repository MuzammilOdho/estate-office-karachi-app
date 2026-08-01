/// Pakistani government fiscal year: 1 July – 30 June, labeled like
/// "2025-26" for the year starting July 2025. Used to auto-derive
/// payments.fy from the payment date at entry time.
class FiscalYearUtils {
  FiscalYearUtils._();

  static String fyForDate(DateTime date) {
    final startYear = date.month >= 7 ? date.year : date.year - 1;
    return _label(startYear);
  }

  /// Recent fiscal years (current first), for the export screen's picker.
  static List<String> recentFYs({int count = 6}) {
    final now = DateTime.now();
    final currentStartYear = now.month >= 7 ? now.year : now.year - 1;
    return List.generate(count, (i) => _label(currentStartYear - i));
  }

  static String _label(int startYear) {
    final endYearShort = (startYear + 1) % 100;
    return '$startYear-${endYearShort.toString().padLeft(2, '0')}';
  }
}