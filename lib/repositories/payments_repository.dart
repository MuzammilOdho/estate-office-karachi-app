import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../config/constants.dart';
import '../models/payment_model.dart';
import '../services/pocketbase_service.dart';
import '../utils/app_exception.dart';
import '../utils/fiscal_year_utils.dart';
import '../utils/paged_result.dart';
import 'audit_log_repository.dart';

class PaymentsRepository {
  final AuditLogRepository _auditLogRepository = AuditLogRepository();

  PocketBase get _pb => PocketBaseService.instance.client;

  /// Page size for the payment-history list. Long-occupied units
  /// accumulate many payments over the years; loading 50 at a time keeps
  /// first paint fast while "load more on scroll" fetches the rest.
  static const historyPerPage = 50;

  /// One page of a payment history, newest first. Callers fetch page 1
  /// on open and request further pages via [page] as the user scrolls.
  Future<PagedResult<PaymentModel>> getHistoryForAllotment(
    String allotmentId, {
    int page = 1,
    int perPage = historyPerPage,
  }) async {
    try {
      final result = await _pb.collection(Collections.payments).getList(
        page: page,
        perPage: perPage,
        filter: _pb.filter(
          'allotment = {:allotmentId}',
          {'allotmentId': allotmentId},
        ),
        sort: '-date',
        expand: 'created_by',
      );
      final items = result.items
          .map((r) => PaymentModel.fromRecord(r, _pb))
          .toList();
      return PagedResult(
        items: items,
        page: result.page,
        perPage: result.perPage,
        totalItems: result.totalItems,
        totalPages: result.totalPages,
      );
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
