import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/allotment_model.dart';
import '../models/allottee_model.dart';
import '../models/payment_model.dart';
import '../repositories/payments_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../widgets/state_views.dart';

/// Read-only — no "Add payment" button. A vacated allotment is history,
/// not something new activity should be recorded against; only the
/// unit's *current* allotment (shown from Unit Detail) allows that.
class AllotmentDetailScreen extends StatefulWidget {
  final AllotmentModel allotment;
  final AllotteeModel allottee;

  const AllotmentDetailScreen({
    super.key,
    required this.allotment,
    required this.allottee,
  });

  @override
  State<AllotmentDetailScreen> createState() => _AllotmentDetailScreenState();
}

enum _LoadState { loading, loaded, error }

class _AllotmentDetailScreenState extends State<AllotmentDetailScreen> {
  final _paymentsRepository = PaymentsRepository();
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  List<PaymentModel> _payments = [];

  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _state = _LoadState.loading;
      _errorMessage = null;
    });
    try {
      final payments =
      await _paymentsRepository.getHistoryForAllotment(widget.allotment.id);
      if (!mounted) return;
      setState(() {
        _payments = payments;
        _state = _LoadState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is AppException ? e.message : 'Something went wrong.';
        _state = _LoadState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allottee = widget.allottee;
    final allotment = widget.allotment;

    return Scaffold(
      appBar: AppBar(title: Text(allottee.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!allotment.isActive)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.vacantGray.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: AppColors.vacantGray),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This allotment has ended. This view is read-only.',
                        style: TextStyle(color: AppColors.vacantGray, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            Text('Allottee', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _InfoRow(label: 'Name', value: allottee.name),
            _InfoRow(
              label: 'CNIC',
              value: allottee.cnic.isEmpty ? 'Not on record' : allottee.cnic,
              monospace: true,
            ),
            if (allottee.designation.isNotEmpty)
              _InfoRow(label: 'Designation', value: allottee.designation),
            if (allottee.department.isNotEmpty)
              _InfoRow(label: 'Department', value: allottee.department),
            if (allottee.bs.isNotEmpty) _InfoRow(label: 'BS', value: allottee.bs),
            const SizedBox(height: 16),
            Text('Allotment', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Date allotted',
              value: _dateFormat.format(allotment.dateOfAllotment),
            ),
            _InfoRow(
              label: 'Date occupied',
              value: _dateFormat.format(allotment.dateOfOccupation),
            ),
            if (allotment.dateOfVacancy != null)
              _InfoRow(
                label: 'Date vacated',
                value: _dateFormat.format(allotment.dateOfVacancy!),
              ),
            const SizedBox(height: 20),
            Text('Payment history', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildPayments(),
          ],
        ),
      ),
    );
  }

  Widget _buildPayments() {
    switch (_state) {
      case _LoadState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: LoadingView(),
        );
      case _LoadState.error:
        return ErrorRetryView(
          message: _errorMessage ?? 'Something went wrong.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        if (_payments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No payments recorded for this allotment.',
              style: TextStyle(color: AppColors.vacantGray),
            ),
          );
        }
        return Column(children: _payments.map((p) => _PaymentTile(payment: p)).toList());
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;

  const _InfoRow({required this.label, required this.value, this.monospace = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: AppColors.vacantGray)),
          ),
          Expanded(
            child: Text(value, style: monospace ? AppTheme.numericData : null),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final PaymentModel payment;
  const _PaymentTile({required this.payment});

  @override
  Widget build(BuildContext context) {
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
            errorBuilder: (_, __, ___) =>
            const Icon(Icons.receipt_long_outlined, color: AppColors.vacantGray),
          ),
        )
            : const Icon(Icons.receipt_long_outlined, color: AppColors.vacantGray),
        title: Text(
          'FY ${payment.fy} · ${DateFormat('dd MMM yyyy').format(payment.date)}',
          style: AppTheme.numericData.copyWith(fontSize: 13),
        ),
        subtitle: Text('Challan #${payment.challanNo} · Added by ${payment.addedByName}'),
        trailing: Text(
          'Rs. ${payment.amountPaid.toStringAsFixed(0)}',
          style: AppTheme.numericData,
        ),
        onTap: payment.challanImageUrl.isEmpty
            ? null
            : () => showDialog(
          context: context,
          builder: (_) => Dialog(
            child: InteractiveViewer(
              child: Image.network(payment.challanImageUrl),
            ),
          ),
        ),
      ),
    );
  }
}