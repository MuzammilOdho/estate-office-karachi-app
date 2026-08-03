import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/allotment_model.dart';
import '../models/allottee_model.dart';
import '../models/payment_model.dart';
import '../repositories/payments_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/payment_list.dart';

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

class _AllotmentDetailScreenState extends State<AllotmentDetailScreen> {
  final _paymentsRepository = PaymentsRepository();

  static final _dateFormat = DateFormat('dd MMM yyyy');

  Future<List<PaymentModel>> _loadPaymentsPage(int page) async {
    final result = await _paymentsRepository.getHistoryForAllotment(
      widget.allotment.id,
      page: page,
    );
    return result.items;
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
            PaymentList(
              loadPage: _loadPaymentsPage,
            ),
          ],
        ),
      ),
    );
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
