import 'package:intl/intl.dart';

/// Government of Pakistan financial year: 1 July – 30 June.
class FinancialYearUtils {
  FinancialYearUtils._();

  static int calendarYearFor(DateTime date) => date.year;

  /// Returns the financial year label, e.g. "2025-26" for a date in FY 2025-26.
  static String financialYearFor(DateTime date) {
    final startYear = date.month >= 7 ? date.year : date.year - 1;
    final endYearShort = (startYear + 1) % 100;
    return '$startYear-${endYearShort.toString().padLeft(2, '0')}';
  }

  static final DateFormat _monthFormat = DateFormat('MMM yyyy');

  /// Payment month label derived from payment date (e.g. "Jul 2026").
  static String paymentMonthFor(DateTime date) => _monthFormat.format(date);
}
