import 'package:estate_registry/models/export_row.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExportRow', () {
    test('vacant-unit row has null dates and empty payment fields', () {
      const row = ExportRow(
        type: 'House',
        houseNo: 'H-1',
        block: 'A',
        flatNo: '',
        colony: 'Clifton',
        personalNo: '',
        allotteeName: '',
        designation: '',
        bs: '',
        department: '',
        cnic: '',
      );
      expect(row.dateOfOccupation, isNull);
      expect(row.dateOfAllotment, isNull);
      expect(row.dob, isNull);
      expect(row.dateOfRetirement, isNull);
      expect(row.paymentDate, isNull);
      expect(row.amountRecovered, 0);
      expect(row.remarks, '');
    });

    test('allotment-without-payment row has dates but null payment date', () {
      final row = ExportRow(
        type: 'House',
        houseNo: 'H-1',
        block: 'A',
        flatNo: '',
        colony: 'Clifton',
        personalNo: 'P-1',
        allotteeName: 'Ali',
        designation: 'Clerk',
        bs: '12',
        department: 'Rev',
        cnic: '42101-1234567-1',
        dateOfOccupation: DateTime(2020, 1, 1),
        dateOfAllotment: DateTime(2019, 12, 1),
        dob: DateTime(1980, 5, 5),
        dateOfRetirement: DateTime(2040, 5, 5),
      );
      expect(row.dateOfOccupation, isNotNull);
      expect(row.dateOfAllotment, isNotNull);
      expect(row.paymentDate, isNull); // no payment
      expect(row.amountRecovered, 0);
    });

    test('payment row has all fields populated', () {
      final row = ExportRow(
        type: 'Flat',
        houseNo: '',
        block: 'B',
        flatNo: 'F-2',
        colony: 'Gulshan',
        personalNo: 'P-2',
        allotteeName: 'Bobi',
        designation: 'Officer',
        bs: '17',
        department: 'Admin',
        cnic: '42101-7654321-2',
        dateOfOccupation: DateTime(2021, 6, 15),
        dateOfAllotment: DateTime(2021, 5, 1),
        paymentDate: DateTime(2026, 7, 10),
        amountRecovered: 5000,
        remarks: 'Challan #99',
      );
      expect(row.paymentDate, isNotNull);
      expect(row.amountRecovered, 5000);
      expect(row.remarks, 'Challan #99');
    });
  });
}
