import 'package:estate_registry/repositories/units_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the pure filter-composition logic behind the advanced search:
/// which clauses each filter field produces, that blank fields are
/// skipped, and that every provided field ANDs together (the House No.
/// criterion being one parenthesized OR group over the three identifier
/// columns).
void main() {
  group('UnitsRepository.buildSearchFilterParts', () {
    test('all-empty input produces no clauses and no params', () {
      final parts = UnitsRepository.buildSearchFilterParts();
      expect(parts.isEmpty, isTrue);
      expect(parts.requiresAllotmentJoin, isFalse);
      expect(parts.params, isEmpty);
    });

    test('blank/whitespace-only fields are treated as empty', () {
      final parts = UnitsRepository.buildSearchFilterParts(
        type: '   ',
        houseNo: ' ',
        cnic: '',
        name: '\t',
        personalNo: '  ',
      );
      expect(parts.isEmpty, isTrue);
    });

    test('type only → one unit clause, no allotment join', () {
      final parts = UnitsRepository.buildSearchFilterParts(type: 'Type A');
      expect(parts.unitClauses, hasLength(1));
      expect(parts.allotteeClauses, isEmpty);
      expect(parts.requiresAllotmentJoin, isFalse);
      expect(parts.params['type'], 'Type A');
    });

    test('house no only → OR group over house/block/flat, no allotment join', () {
      final parts = UnitsRepository.buildSearchFilterParts(houseNo: '12');
      final clause = parts.unitClauses.single;
      expect(clause.fields, ['house_no', 'block', 'flat_no']);
      expect(clause.paramName, 'houseNo');
      expect(clause.paramValue, '12');
      expect(parts.requiresAllotmentJoin, isFalse);
    });

    test('any allottee field → requires allotment join', () {
      for (final parts in [
        UnitsRepository.buildSearchFilterParts(name: 'Ali'),
        UnitsRepository.buildSearchFilterParts(cnic: '42101'),
        UnitsRepository.buildSearchFilterParts(personalNo: '99'),
      ]) {
        expect(parts.requiresAllotmentJoin, isTrue,
            reason: 'allottee field must route the query through allotments');
      }
    });

    test('unit fields alone do not require the allotment join', () {
      final parts =
          UnitsRepository.buildSearchFilterParts(type: 'A', houseNo: '9');
      expect(parts.requiresAllotmentJoin, isFalse);
    });

    test('values are trimmed before binding', () {
      final parts =
          UnitsRepository.buildSearchFilterParts(name: '  Ali Khan  ');
      expect(parts.params['name'], 'Ali Khan');
    });

    test('all five filters → all clauses and all params present', () {
      final parts = UnitsRepository.buildSearchFilterParts(
        type: 'A',
        houseNo: '12',
        name: 'Ali',
        cnic: '42101-1234567-1',
        personalNo: '99',
      );
      expect(parts.unitClauses, hasLength(2)); // type + house-no group
      expect(parts.allotteeClauses, hasLength(3)); // name + cnic + personal no
      expect(parts.requiresAllotmentJoin, isTrue);
      expect(
        parts.params.keys,
        unorderedEquals(['type', 'houseNo', 'name', 'cnic', 'personalNo']),
      );
    });
  });

  group('UnitsRepository.searchFilterTemplate', () {
    test('units path AND-joins clauses, no vacancy condition', () {
      final parts =
          UnitsRepository.buildSearchFilterParts(type: 'A', houseNo: '12');
      expect(
        UnitsRepository.searchFilterTemplate(parts, viaAllotments: false),
        'type ~ {:type} && '
            '(house_no ~ {:houseNo} || block ~ {:houseNo} || flat_no ~ {:houseNo})',
      );
    });

    test('allotments path prefixes unit fields and requires active allotment', () {
      final parts = UnitsRepository.buildSearchFilterParts(type: 'A', cnic: '42101');
      expect(
        UnitsRepository.searchFilterTemplate(parts, viaAllotments: true),
        'date_of_vacancy = {:empty} && unit.type ~ {:type} && '
            'allottee.cnic ~ {:cnic}',
      );
    });

    test('all five filters AND together on the allotments path', () {
      final parts = UnitsRepository.buildSearchFilterParts(
        type: 'A',
        houseNo: '12',
        name: 'Ali',
        cnic: '42101',
        personalNo: '99',
      );
      final template =
          UnitsRepository.searchFilterTemplate(parts, viaAllotments: true);
      expect(template, startsWith('date_of_vacancy = {:empty} &&'));
      expect(template, contains('unit.type ~ {:type}'));
      expect(
        template,
        contains('(unit.house_no ~ {:houseNo} || unit.block ~ {:houseNo} '
            '|| unit.flat_no ~ {:houseNo})'),
      );
      expect(template, contains('allottee.name ~ {:name}'));
      expect(template, contains('allottee.cnic ~ {:cnic}'));
      expect(template, contains('allottee.personal_no ~ {:personalNo}'));
      // 6 clauses (vacancy + 5 filters) → exactly 5 AND separators.
      expect(' && '.allMatches(template), hasLength(5));
    });

    test('single-field templates have no AND separator', () {
      final parts = UnitsRepository.buildSearchFilterParts(personalNo: '99');
      expect(
        UnitsRepository.searchFilterTemplate(parts, viaAllotments: true),
        'date_of_vacancy = {:empty} && allottee.personal_no ~ {:personalNo}',
      );
    });
  });
}
