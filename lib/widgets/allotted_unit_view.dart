import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/allotment_model.dart';
import '../models/allottee_model.dart';
import '../models/payment_model.dart';
import '../providers/auth_provider.dart';
import '../repositories/allotments_repository.dart';
import '../repositories/payments_repository.dart';
import '../screens/allottee_history_screen.dart';
import '../screens/modify_allottee_sheet.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import 'payment_list.dart';

class AllottedUnitView extends StatefulWidget {
  final String unitLabel;
  final AllotmentModel allotment;
  final AllotteeModel allottee;
  final VoidCallback onRecordPayment;
  final VoidCallback onAllotteeModified;
  final VoidCallback onVacated;

  const AllottedUnitView({
    super.key,
    required this.unitLabel,
    required this.allotment,
    required this.allottee,
    required this.onRecordPayment,
    required this.onAllotteeModified,
    required this.onVacated,
  });

  @override
  State<AllottedUnitView> createState() => _AllottedUnitViewState();
}

class _AllottedUnitViewState extends State<AllottedUnitView> {
  final _allotmentsRepository = AllotmentsRepository();
  final _paymentsRepository = PaymentsRepository();
  bool _isVacating = false;
  String? _errorMessage;

  static final _dateFormat = DateFormat('dd MMM yyyy');

  Future<List<PaymentModel>> _loadPaymentsPage(int page) async {
    final result = await _paymentsRepository.getHistoryForAllotment(
      widget.allotment.id,
      page: page,
    );
    return result.items;
  }

  Future<void> _confirmVacate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vacate this unit?'),
        content: Text(
          "This will end ${widget.allottee.name}'s allotment and mark the "
              'unit vacant.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Vacate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _vacate();
  }

  Future<void> _vacate() async {
    setState(() {
      _isVacating = true;
      _errorMessage = null;
    });
    try {
      await _allotmentsRepository.vacateAllotment(
        allotmentId: widget.allotment.id,
        dateOfVacancy: DateTime.now(),
        unitLabel: widget.unitLabel,
        allotteeName: widget.allottee.name,
      );
      if (!mounted) return;
      widget.onVacated();
    } catch (e) {
      setState(() {
        _errorMessage = e is AppException ? e.message : 'Something went wrong.';
      });
    } finally {
      if (mounted) setState(() => _isVacating = false);
    }
  }

  void _openModify() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ModifyAllotteeSheet(allottee: widget.allottee),
    ).then((changed) {
      if (changed == true) widget.onAllotteeModified();
    });
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AllotteeHistoryScreen(
          allotteeId: widget.allottee.id,
          allotteeName: widget.allottee.name,
        ),
      ),
    );
  }

  String get _dobDisplay {
    final dob = widget.allottee.dob;
    final age = widget.allottee.ageYears;
    if (dob == null) return 'Not on record';
    return '${_dateFormat.format(dob)} ($age yrs)';
  }

  @override
  Widget build(BuildContext context) {
    final allottee = widget.allottee;
    final allotment = widget.allotment;
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Allottee', style: Theme.of(context).textTheme.titleMedium),
            ),
            if (isAdmin)
              IconButton(
                tooltip: 'Modification history',
                icon: const Icon(Icons.history_outlined),
                onPressed: _openHistory,
              ),
          ],
        ),
        const SizedBox(height: 4),
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
        _InfoRow(label: 'Date of birth', value: _dobDisplay),
        _InfoRow(label: 'Status', value: allottee.serviceStatusLabel),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _openModify,
          icon: const Icon(Icons.edit_note_outlined),
          label: const Text('Modify allottee info'),
        ),
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
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: widget.onRecordPayment,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Add payment'),
        ),
        const SizedBox(height: 24),
        Text('Payment history', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        PaymentList(
          loadPage: _loadPaymentsPage,
          showAmountDue: true,
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null) ...[
          Text(_errorMessage!, style: const TextStyle(color: AppColors.dueRed)),
          const SizedBox(height: 8),
        ],
        if (isAdmin)
          OutlinedButton.icon(
            onPressed: _isVacating ? null : _confirmVacate,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.dueRed),
            icon: _isVacating
                ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.logout),
            label: const Text('Vacate unit'),
          ),
      ],
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
