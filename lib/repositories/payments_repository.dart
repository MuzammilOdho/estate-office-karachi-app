import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../config/constants.dart';
import '../models/payment_model.dart';
import '../services/pocketbase_service.dart';
import '../utils/app_exception.dart';
import '../utils/fiscal_year_utils.dart';
import 'audit_log_repository.dart';

class PaymentsRepository {
  final AuditLogRepository _auditLogRepository = AuditLogRepository();

  PocketBase get _pb => PocketBaseService.instance.client;

  Future<List<PaymentModel>> getHistoryForAllotment(String allotmentId) async {
    try {
      final records = await _pb.collection(Collections.payments).getFullList(
        filter: _pb.filter(
          'allotment = {:allotmentId}',
          {'allotmentId': allotmentId},
        ),
        sort: '-date',
        expand: 'created_by',
      );
      return records.map((r) => PaymentModel.fromRecord(r, _pb)).toList();
    } catch (e) {
      throw asAppException(e);
    }
  }

  Future<PaymentModel> createPayment({
    required String allotmentId,
    required DateTime date,
    required double amountPaid,
    double amountDue = 0,
    required String challanNo,
    String remarks = '',
    required List<int> imageBytes,
    String imageFilename = 'challan.jpg',
    String unitLabel = '',
    String allotteeName = '',
  }) async {
    RecordModel record;
    try {
      record = await _pb.collection(Collections.payments).create(
        body: {
          'allotment': allotmentId,
          'date': date.toIso8601String(),
          'fy': FiscalYearUtils.fyForDate(date),
          'amount_paid': amountPaid,
          'amount_due': amountDue,
          'challan_no': challanNo.trim(),
          'remarks': remarks.trim(),
          if (_pb.authStore.record?.id != null) 'created_by': _pb.authStore.record!.id,
        },
        files: [
          http.MultipartFile.fromBytes(
            'challan_image',
            imageBytes,
            filename: imageFilename,
          ),
        ],
      );
    } catch (e) {
      throw asAppException(e);
    }

    final payment = PaymentModel.fromRecord(record, _pb);

    await _auditLogRepository.logBestEffort(
      action: 'payment_added',
      entityType: Collections.payments,
      entityId: payment.id,
      summary:
      'Payment of Rs. ${amountPaid.toStringAsFixed(0)} recorded for '
          '${allotteeName.isNotEmpty ? allotteeName : "allotment $allotmentId"}'
          '${unitLabel.isNotEmpty ? " ($unitLabel)" : ""}',
    );

    return payment;
  }
}