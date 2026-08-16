import 'package:pocketbase/pocketbase.dart';

import '../utils/user_display.dart';

class PaymentModel {
  final String id;
  final String allotmentId;
  final String fy; // "2025-26" — auto-derived from date at creation time
  final DateTime date;
  final double amountPaid;
  final double amountDue; // optional, defaults 0, report-only
  final String challanNo;
  final String challanImageFilename;
  final String challanImageUrl;
  final String remarks;
  final String addedByName;

  const PaymentModel({
    required this.id,
    required this.allotmentId,
    required this.fy,
    required this.date,
    required this.amountPaid,
    required this.amountDue,
    required this.challanNo,
    required this.challanImageFilename,
    required this.challanImageUrl,
    required this.remarks,
    required this.addedByName,
  });

  /// [record] should have been fetched with `expand: 'created_by'` for
  /// [addedByName] to resolve to anything other than "Unknown".
  factory PaymentModel.fromRecord(RecordModel record, PocketBase pb) {
    final filename = record.get<String>('challan_image', '');
    final rawDate = record.get<String>('date', '');
    final createdByRecord =
    record.get<RecordModel>('expand.created_by', null);

    return PaymentModel(
      id: record.id,
      allotmentId: record.get<String>('allotment', ''),
      fy: record.get<String>('fy', ''),
      date: DateTime.tryParse(rawDate) ?? DateTime.now(),
      amountPaid: record.get<double>('amount_paid', 0),
      amountDue: record.get<double>('amount_due', 0),
      challanNo: record.get<String>('challan_no', ''),
      challanImageFilename: filename,
      challanImageUrl:
      filename.isEmpty ? '' : pb.files.getURL(record, filename).toString(),
      remarks: record.get<String>('remarks', ''),
      addedByName: UserDisplay.nameFromRecord(createdByRecord),
    );
  }
}