import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/export_row.dart';
import 'app_exception.dart';

/// Builds the CSV matching the office's existing register format: one
/// row per payment, with the payment date split into separate
/// Date/Month/Year columns and Amount Due/Amount Recovered/Balance at
/// the end.
class CsvExport {
  CsvExport._();

  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _monthFormat = DateFormat('MMMM');

  static const _headers = [
    'S.No',
    'FY',
    'Flat No./Quarter/House No.',
    'Category/Type',
    'Location',
    'Name',
    'Designation',
    'Department',
    'Original Date of Allotment',
    'Date of Occupation',
    'Date of Birth',
    'Date',
    'Month',
    'Year',
    'Amount Due',
    'Amount Recovered',
    'Balance',
  ];

  /// Writes the CSV header and then each row from [rows] as it arrives,
  /// flushing to [sink] incrementally. Memory stays at one row at a time
  /// regardless of export size — the caller streams rows from the server
  /// page-by-page, and this writes each page's worth to the file and
  /// discards it.
  static Future<int> writeCsvTo(
    Stream<ExportRow> rows,
    StringSink sink, {
    void Function(int)? onRowCount,
  }) async {
    const csv = ListToCsvConverter();
    sink.writeln(csv.convert([_headers]));

    int count = 0;
    await for (final row in rows) {
      count++;
      // convert() takes a list of rows, so wrap the single row.
      sink.writeln(csv.convert([
        [
          count,
          row.fy,
          row.unitLabel,
          row.type,
          row.colony,
          row.allotteeName,
          row.designation,
          row.department,
          _dateFormat.format(row.dateOfAllotment),
          _dateFormat.format(row.dateOfOccupation),
          row.dob == null ? '' : _dateFormat.format(row.dob!),
          row.paymentDate.day,
          _monthFormat.format(row.paymentDate),
          row.paymentDate.year,
          row.amountDue,
          row.amountRecovered,
          row.balance,
        ],
      ]));
      onRowCount?.call(count);
    }
    return count;
  }

  /// Streams the CSV from [rows] into a temp file and opens the system
  /// share sheet so staff can send it via WhatsApp/email or save it.
  /// Returns the final row count for the caller to display.
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

      // Open the file for writing and stream the CSV into it.
      final sink = file.openWrite();
      try {
        final count = await writeCsvTo(
          rows,
          sink,
          onRowCount: onRowCount,
        );
        await sink.flush();
        await sink.close();

        // Nothing to share if the stream yielded no rows.
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
