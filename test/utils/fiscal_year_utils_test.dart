import 'package:estate_registry/utils/fiscal_year_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FiscalYearUtils.fyForDate', () {
    test('July 1 starts a new FY', () {
      expect(FiscalYearUtils.fyForDate(DateTime(2025, 7, 1)), '2025-26');
    });

    test('June 30 is the last day of the prior FY', () {
      expect(FiscalYearUtils.fyForDate(DateTime(2026, 6, 30)), '2025-26');
    });

    test('Dec 31 is mid-FY', () {
      expect(FiscalYearUtils.fyForDate(DateTime(2025, 12, 31)), '2025-26');
    });

    test('Jan 1 is early in the FY that started last July', () {
      expect(FiscalYearUtils.fyForDate(DateTime(2026, 1, 1)), '2025-26');
    });

    test('Aug 15 is mid-FY', () {
      expect(FiscalYearUtils.fyForDate(DateTime(2026, 8, 15)), '2026-27');
    });
  });

  group('FiscalYearUtils.recentFYs', () {
    test('returns the requested count', () {
      expect(FiscalYearUtils.recentFYs(count: 3), hasLength(3));
      expect(FiscalYearUtils.recentFYs(count: 10), hasLength(10));
    });

    test('labels match YYYY-YY pattern', () {
      for (final fy in FiscalYearUtils.recentFYs(count: 6)) {
        expect(RegExp(r'^\d{4}-\d{2}$').hasMatch(fy), isTrue,
            reason: '$fy is not a valid FY label');
      }
    });

    test('current FY is first in the list', () {
      final fys = FiscalYearUtils.recentFYs(count: 5);
      final now = DateTime.now();
      final expectedCurrent = FiscalYearUtils.fyForDate(now);
      expect(fys.first, expectedCurrent);
    });
  });
}
