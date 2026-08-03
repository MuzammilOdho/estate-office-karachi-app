import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/payment_model.dart';
import '../theme/app_theme.dart';

/// One payment row in any list that shows a unit/allotment's payment
/// history. Shared between AllottedUnitView (current allotment) and
/// AllotmentDetailScreen (read-only historical view) so they can't
/// diverge — they were previously two identical private copies.
///
/// `cacheWidth`/`cacheHeight` decode the challan thumbnail down to the
/// displayed 44px size (× device pixel ratio) instead of holding a full-
/// resolution image in memory — the main cause of scroll jank when a list
/// has many payments.
class PaymentTile extends StatelessWidget {
  final PaymentModel payment;
  final bool showAmountDue;

  const PaymentTile({super.key, required this.payment, this.showAmountDue = false});

  @override
  Widget build(BuildContext context) {
    // Match the displayed 44×44 leading thumbnail. Rounded up so we never
    // undersample on fractional device pixel ratios.
    final thumbPx = (44 * MediaQuery.devicePixelRatioOf(context)).ceil();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: ListTile(
        leading: payment.challanImageUrl.isNotEmpty
            ? ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            payment.challanImageUrl,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            cacheWidth: thumbPx,
            cacheHeight: thumbPx,
            errorBuilder: (_, __, ___) =>
            const Icon(Icons.receipt_long_outlined, color: AppColors.vacantGray),
          ),
        )
            : const Icon(Icons.receipt_long_outlined, color: AppColors.vacantGray),
        title: Text(
          'FY ${payment.fy} · ${DateFormat('dd MMM yyyy').format(payment.date)}',
          style: AppTheme.numericData.copyWith(fontSize: 13),
        ),
        subtitle: Text(
          'Challan #${payment.challanNo} · Added by ${payment.addedByName}'
              '${showAmountDue && payment.amountDue > 0 ? ' · Due: Rs. ${payment.amountDue.toStringAsFixed(0)}' : ''}',
        ),
        trailing: Text(
          'Rs. ${payment.amountPaid.toStringAsFixed(0)}',
          style: AppTheme.numericData,
        ),
        onTap: payment.challanImageUrl.isEmpty
            ? null
            : () => showDialog(
          context: context,
          builder: (_) => Dialog(
            // Full-size on tap — intentionally no cache sizing here.
            child: InteractiveViewer(
              child: Image.network(payment.challanImageUrl),
            ),
          ),
        ),
      ),
    );
  }
}
