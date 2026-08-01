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

  static String buildCsv(List<ExportRow> rows) {
    final data = <List<dynamic>>[_headers];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      data.add([
        i + 1,
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
      ]);
    }
    return const ListToCsvConverter().convert(data);
  }

  /// Writes the CSV to a temp file and opens the system share sheet so
  /// staff can send it via WhatsApp/email or save it.
  static Future<void> shareCsv({
    required List<ExportRow> rows,
    required String reportLabel,
    required String periodLabel,
  }) async {
    try {
      final csvString = buildCsv(rows);
      final dir = await getTemporaryDirectory();
      final safeName =
      '${reportLabel}_$periodLabel'.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File('${dir.path}/$safeName.csv');
      await file.writeAsString(csvString);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: '$reportLabel — $periodLabel',
          text: '$reportLabel — $periodLabel',
        ),
      );
    } catch (e) {
      throw asAppException(e);
    }
  }
}