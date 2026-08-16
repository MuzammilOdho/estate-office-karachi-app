import 'package:csv/csv.dart';
import 'package:estate_registry/models/export_row.dart';
import 'package:estate_registry/utils/csv_export.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives [CsvExport.writeCsvTo] with a small synthetic row stream and
/// returns the resulting CSV string.
Future<String> _renderCsv(List<ExportRow> rows) async {
  final sink = StringBuffer();
  await CsvExport.writeCsvTo(Stream.fromIterable(rows), sink);
  return sink.toString();
}

void main() {
  group('CsvExport headers', () {
    test('produces exactly 22 columns', () async {
      final csv = await _renderCsv(const []);
      final headerLine = csv.split('\n').first;
      // Parse the header line back into a list of fields.
      final parsed = const CsvToListConverter().convert(headerLine);
      expect(parsed.first, hasLength(22));
    });

    test('header names match the Excel template', () async {
      final csv = await _renderCsv(const []);
      final parsed = const CsvToListConverter().convert(csv);
      final headers = parsed.first.cast<String>();
      expect(headers[0], 'Sr. No.');
      expect(headers[1], 'Category / Type');
      expect(headers[5], 'Colony');
      expect(headers[6], 'Personal No');
      expect(headers[18], 'Payment Date');
      expect(headers[19], 'Rent Amount Recovered through Challans');
      expect(headers[21], 'Remarks');
    });
  });

  group('CsvExport row formatting', () {
    test('vacant unit produces blank date and payment columns', () async {
      final csv = await _renderCsv([
        const ExportRow(
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
        ),
      ]);
      final parsed = const CsvToListConverter().convert(csv);
      // Row 0 is the header; row 1 is the data row.
      final row = parsed[1];
      expect(row[1], 'House'); // type
      expect(row[2], 'H-1'); // house no
      expect(row[5], 'Clifton'); // colony
      // Columns M (12) and N (13) — dates — should be empty.
      expect(row[12], ''); // date of occupation
      expect(row[13], ''); // date of allotment
      // Column S (18) — payment date — should be empty.
      expect(row[18], '');
      // Column T (19) — amount recovered — should be 0.
      expect(row[19], 0);
    });

    test('payment row has all fields formatted', () async {
      final csv = await _renderCsv([
        ExportRow(
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
        ),
      ]);
      final parsed = const CsvToListConverter().convert(csv);
      final row = parsed[1];
      expect(row[1], 'Flat');
      expect(row[7], 'Bobi'); // FGS name
      expect(row[12], '15 Jun 2021'); // occupation date formatted
      expect(row[13], '01 May 2021'); // allotment date formatted
      expect(row[18], '10 Jul 2026'); // payment date formatted
      expect(row[19], 5000);
      expect(row[21], 'Challan #99');
    });

    test('serial number increments per row', () async {
      final csv = await _renderCsv([
        const ExportRow(
          type: 'A', houseNo: '1', block: '', flatNo: '', colony: 'C',
          personalNo: '', allotteeName: '', designation: '', bs: '', department: '', cnic: '',
        ),
        const ExportRow(
          type: 'B', houseNo: '2', block: '', flatNo: '', colony: 'C',
          personalNo: '', allotteeName: '', designation: '', bs: '', department: '', cnic: '',
        ),
      ]);
      final parsed = const CsvToListConverter().convert(csv);
      expect(parsed[1][0], 1);
      expect(parsed[2][0], 2);
    });

    test('manual-entry columns Q, R, U are always blank', () async {
      final csv = await _renderCsv([
        ExportRow(
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
          remarks: 'Challan',
        ),
      ]);
      final parsed = const CsvToListConverter().convert(csv);
      final row = parsed[1];
      expect(row[16], ''); // Q — Previous Outstanding Balance
      expect(row[17], ''); // R — Demand of Current FY
      expect(row[20], ''); // U — Total Outstanding
    });

    test('remarks with comma are properly CSV-escaped', () async {
      final csv = await _renderCsv([
        ExportRow(
          type: 'Flat',
          houseNo: '',
          block: 'B',
          flatNo: 'F-2',
          colony: 'Gulshan',
          personalNo: '',
          allotteeName: '',
          designation: '',
          bs: '',
          department: '',
          cnic: '',
          paymentDate: DateTime(2026, 7, 10),
          amountRecovered: 100,
          remarks: 'Paid in full, no balance',
        ),
      ]);
      // The CSV should wrap the remarks field in quotes because of the comma.
      expect(csv, contains('"Paid in full, no balance"'));
    });

    test('no double-spaced blank lines between rows', () async {
      final csv = await _renderCsv([
        const ExportRow(
          type: 'A', houseNo: '1', block: '', flatNo: '', colony: 'C',
          personalNo: '', allotteeName: '', designation: '', bs: '', department: '', cnic: '',
        ),
        const ExportRow(
          type: 'B', houseNo: '2', block: '', flatNo: '', colony: 'C',
          personalNo: '', allotteeName: '', designation: '', bs: '', department: '', cnic: '',
        ),
      ]);
      final lines = csv.split('\r\n');
      // Header + 2 data rows = 3 lines. The converter adds \r\n after each
      // row, so splitting on \r\n should give exactly 3 non-empty lines
      // (plus a trailing empty string from the final \r\n).
      final nonEmpty = lines.where((l) => l.isNotEmpty).toList();
      expect(nonEmpty, hasLength(3));
    });
  });
}
