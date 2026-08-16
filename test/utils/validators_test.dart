import 'package:estate_registry/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.cnic', () {
    test('null when empty (optional)', () {
      expect(Validators.cnic(''), isNull);
      expect(Validators.cnic(null), isNull);
      expect(Validators.cnic('   '), isNull);
    });

    test('error when not 13 digits', () {
      expect(Validators.cnic('42101-1234567'), isNotNull); // 12 digits
      expect(Validators.cnic('42101-1234567-12'), isNotNull); // 14 digits
    });

    test('null when exactly 13 digits', () {
      expect(Validators.cnic('42101-1234567-1'), isNull);
    });
  });

  group('Validators.phone', () {
    test('null when empty (optional)', () {
      expect(Validators.phone(''), isNull);
      expect(Validators.phone(null), isNull);
    });

    test('error when not 11 digits', () {
      expect(Validators.phone('0300-123456'), isNotNull); // 10 digits
      expect(Validators.phone('0300-12345678'), isNotNull); // 12 digits
    });

    test('error when does not start with 03', () {
      expect(Validators.phone('1234-5678901'), isNotNull);
    });

    test('null when valid 03XX-XXXXXXX', () {
      expect(Validators.phone('0300-1234567'), isNull);
      expect(Validators.phone('0321-9876543'), isNull);
    });
  });

  group('Validators.required', () {
    test('error when empty or whitespace', () {
      expect(Validators.required(''), isNotNull);
      expect(Validators.required('   '), isNotNull);
      expect(Validators.required(null), isNotNull);
    });

    test('null when non-empty', () {
      expect(Validators.required('hello'), isNull);
    });
  });

  group('Validators.positiveNumber', () {
    test('error when empty', () {
      expect(Validators.positiveNumber(''), isNotNull);
    });

    test('error when zero or negative', () {
      expect(Validators.positiveNumber('0'), isNotNull);
      expect(Validators.positiveNumber('-5'), isNotNull);
    });

    test('error when not a number', () {
      expect(Validators.positiveNumber('abc'), isNotNull);
    });

    test('null when positive number', () {
      expect(Validators.positiveNumber('100'), isNull);
      expect(Validators.positiveNumber('1.5'), isNull);
    });
  });
}
