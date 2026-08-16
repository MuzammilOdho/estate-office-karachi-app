import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/export_row.dart';
import 'app_exception.dart';

/// Builds the CSV matching the office's Excel register layout (22 columns).
/// Columns Q, R, U are left blank for manual entry in Excel.
class CsvExport {
  CsvExport._();

  static final _dateFormat = DateFormat('dd MMM yyyy');

  /// Headers matching the Excel template exactly (A–V).
  static const _headers = [
    'Sr. No.',
    'Category / Type',
    'House No',
    'Block No.',
    'Flat No',
    'Colony',
    'Personal No',
    'FGS Name',
    'FGS Designation',
    'BS',
    'Department',
    'FGS CNIC',
    'Date Of Occupation',
    'Allotment Date',
    'Date Of Birth',
    'Date of Retirement',
    'Previous Outstanding Balance',    // Q — manual
    'Demand of Current FY',             // R — manual
    'Payment Date',                     // S — new
    'Rent Amount Recovered through Challans', // T
    'Total Outstanding',                // U — manual
    'Remarks',                          // V
  ];

  /// Writes the CSV header and then each row from [rows] as it arrives,
  /// flushing to [sink] incrementally. Memory stays at one row at a time.
  static Future<int> writeCsvTo(
    Stream<ExportRow> rows,
    StringSink sink, {
    void Function(int)? onRowCount,
  }) async {
    const csv = ListToCsvConverter();
    sink.write(csv.convert([_headers]));
    sink.write('\r\n');

    int count = 0;
    await for (final row in rows) {
      count++;
      sink.write(csv.convert([
        [
          count,                                    // A — Sr. No.
          row.type,                                 // B — Category / Type
          row.houseNo,                              // C — House No
          row.block,                                // D — Block No.
          row.flatNo,                               // E — Flat No
          row.colony,                               // F — Colony
          row.personalNo,                           // G — Personal No
          row.allotteeName,                         // H — FGS Name
          row.designation,                          // I — FGS Designation
          row.bs,                                   // J — BS
          row.department,                           // K — Department
          row.cnic,                                 // L — FGS CNIC
          row.dateOfOccupation == null
              ? ''
              : _dateFormat.format(row.dateOfOccupation!), // M — Date Of Occupation
          row.dateOfAllotment == null
              ? ''
              : _dateFormat.format(row.dateOfAllotment!),  // N — Allotment Date
          row.dob == null ? '' : _dateFormat.format(row.dob!), // O — Date Of Birth
          row.dateOfRetirement == null
              ? ''
              : _dateFormat.format(row.dateOfRetirement!), // P — Date of Retirement
          '', // Q — Previous Outstanding Balance (manual)
          '', // R — Demand of Current FY (manual)
          row.paymentDate == null
              ? ''
              : _dateFormat.format(row.paymentDate!), // S — Payment Date
          row.amountRecovered, // T — Rent Amount Recovered through Challans
          '', // U — Total Outstanding (manual)
          row.remarks, // V — Remarks
        ],
      ]));
      sink.write('\r\n');
      onRowCount?.call(count);
    }
    return count;
  }

  /// Streams the CSV from [rows] into a temp file and opens the system
  /// share sheet so staff can send it via WhatsApp/email or save it.
  static Future<int> shareCsv({
    required Stream<ExportRow> rows,
    required String reportLabel,
    required String periodLabel,
    void Function(int)? onRowCount,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final safeName =
          '${reportLabel}_$periodLabel'.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File('${dir.path}/$safeName.csv');

      final sink = file.openWrite();
      try {
        final count = await writeCsvTo(
          rows,
          sink,
          onRowCount: onRowCount,
        );
        await sink.flush();
        await sink.close();

        if (count == 0) return 0;

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: '$reportLabel — $periodLabel',
            text: '$reportLabel — $periodLabel',
          ),
        );
        return count;
      } catch (e) {
        await sink.close();
        rethrow;
      }
    } catch (e) {
      throw asAppException(e);
    }
  }
}
