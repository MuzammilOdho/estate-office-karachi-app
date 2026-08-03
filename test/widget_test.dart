import 'package:estate_registry/utils/fiscal_year_utils.dart';
import 'package:estate_registry/utils/natural_sort.dart';
import 'package:estate_registry/utils/pocketbase_date_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FiscalYearUtils', () {
    test('fyForDate — July belongs to the FY starting that year', () {
      // 1 July 2025 → FY "2025-26"
      expect(
        FiscalYearUtils.fyForDate(DateTime(2025, 7, 1)),
        '2025-26',
      );
    });

    test('fyForDate — June belongs to the previous FY', () {
      // 30 June 2026 → FY "2025-26" (still the FY that started July 2025)
      expect(
        FiscalYearUtils.fyForDate(DateTime(2026, 6, 30)),
        '2025-26',
      );
    });

    test('fyForDate — Jan belongs to the previous FY', () {
      // 15 Jan 2026 → FY "2025-26"
      expect(
        FiscalYearUtils.fyForDate(DateTime(2026, 1, 15)),
        '2025-26',
      );
    });

    test('recentFYs — returns requested count, current first', () {
      final fys = FiscalYearUtils.recentFYs(count: 4);
      expect(fys, hasLength(4));
      // Labels should match the "YYYY-YY" pattern.
      for (final fy in fys) {
        expect(RegExp(r'^\d{4}-\d{2}$').hasMatch(fy), isTrue);
      }
    });

    test('recentFYs — default count is 6', () {
      expect(FiscalYearUtils.recentFYs(), hasLength(6));
    });
  });

  group('naturalCompare', () {
    test('numeric strings compared by value', () {
      // "2" should come before "10"
      expect(naturalCompare('2', '10'), lessThan(0));
    });

    test('mixed house numbers sorted naturally', () {
      expect(naturalCompare('H-2', 'H-10'), lessThan(0));
    });

    test('plain string fallback when no digits', () {
      expect(naturalCompare('A', 'B'), lessThan(0));
    });

    test('equal values return zero', () {
      expect(naturalCompare('42', '42'), isZero);
    });

    test('flat numbers: "Flat 3" before "Flat 12"', () {
      expect(naturalCompare('Flat 3', 'Flat 12'), lessThan(0));
    });
  });

  group('pbFilterDate', () {
    test('produces space-delimited format ending with Z', () {
      final dt = DateTime(2025, 7, 1, 0, 0, 0, 0);
      final result = pbFilterDate(dt);
      // Should NOT contain 'T' — PocketBase filters need space-delimited dates.
      expect(result, contains(' '));
      expect(result, endsWith('Z'));
      expect(result, isNot(contains('T')));
    });

    test('round-trips to known format', () {
      final dt = DateTime.utc(2025, 12, 15, 9, 30, 45, 123);
      final result = pbFilterDate(dt);
      expect(result, '2025-12-15 09:30:45.123Z');
    });
  });
}
