import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/allotment_model.dart';
import '../models/allottee_model.dart';
import '../models/payment_model.dart';
import '../models/unit_model.dart';
import '../providers/auth_provider.dart';
import '../repositories/allotments_repository.dart';
import '../repositories/allottees_repository.dart';
import '../repositories/payments_repository.dart';
import '../repositories/units_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../widgets/allot_unit_form.dart';
import '../widgets/allotted_unit_view.dart';
import '../widgets/state_views.dart';
import 'export_screen.dart';
import 'record_payment_sheet.dart';
import 'unit_allotment_history_screen.dart';

/// The unit's current status is never read from a stored field — it's
/// simply "did AllotmentsRepository find an active allotment for this
/// unit, yes or no". That's the whole fix for the old bug where a unit
/// could say "allotted" while its allotment record disagreed: there is
/// now only one place that fact lives.
class UnitDetailSheet extends StatefulWidget {
  final String unitId;
  const UnitDetailSheet({super.key, required this.unitId});

  @override
  State<UnitDetailSheet> createState() => _UnitDetailSheetState();
}

class _UnitDetailSheetState extends State<UnitDetailSheet> {
  final _unitsRepository = UnitsRepository();
  final _allotmentsRepository = AllotmentsRepository();
  final _allotteesRepository = AllotteesRepository();
  final _paymentsRepository = PaymentsRepository();

  bool _isLoading = true;
  String? _errorMessage;

  UnitModel? _unit;
  AllotmentModel? _allotment;
  AllotteeModel? _allottee;
  List<PaymentModel> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final unit = await _unitsRepository.getUnit(widget.unitId);
      final allotment = await _allotmentsRepository.getActiveAllotmentForUnit(unit.id);

      AllotteeModel? allottee;
      List<PaymentModel> payments = const [];
      if (allotment != null) {
        allottee = await _allotteesRepository.getAllottee(allotment.allotteeId);
        payments = await _paymentsRepository.getHistoryForAllotment(allotment.id);
      }

      if (!mounted) return;
      setState(() {
        _unit = unit;
        _allotment = allotment;
        _allottee = allottee;
        _payments = payments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is AppException ? e.message : 'Something went wrong.';
        _isLoading = false;
      });
    }
  }

  void _openRecordPayment() {
    final allotment = _allotment;
    if (allotment == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RecordPaymentSheet(
        allotmentId: allotment.id,
        unitLabel: _unit?.displayLabel ?? '',
        allotteeName: _allottee?.name ?? '',
      ),
    ).then((_) => _load());
  }

  void _openExportHistory() {
    final unit = _unit;
    if (unit == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExportScreen(
          initialUnitId: unit.id,
          initialUnitLabel: '${unit.displayLabel} (${unit.colony})',
        ),
      ),
    );
  }

  void _openAllotmentHistory() {
    final unit = _unit;
    if (unit == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UnitAllotmentHistoryScreen(
          unitId: unit.id,
          unitLabel: unit.displayLabel,
        ),
      ),
    );
  }

  void _handleAllotted() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unit allotted.')),
    );
    Navigator.of(context).pop(true);
  }

  void _handleVacated() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unit vacated.')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 240, child: LoadingView());
    }
    if (_errorMessage != null) {
      return SizedBox(
        height: 240,
        child: ErrorRetryView(message: _errorMessage!, onRetry: _load),
      );
    }

    final unit = _unit!;
    final allotment = _allotment;
    final allottee = _allottee;
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text('Unit', style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(
              tooltip: 'Allotment history',
              icon: const Icon(Icons.history_outlined, size: 20),
              onPressed: _openAllotmentHistory,
            ),
            IconButton(
              tooltip: 'Export payment history',
              icon: const Icon(Icons.ios_share_rounded, size: 20),
              onPressed: _openExportHistory,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (unit.houseNo.isNotEmpty)
          _InfoRow(label: 'House no', value: unit.houseNo, monospace: true),
        if (unit.block.isNotEmpty)
          _InfoRow(label: 'Block', value: unit.block, monospace: true),
        if (unit.flatNo.isNotEmpty)
          _InfoRow(label: 'Flat no', value: unit.flatNo, monospace: true),
        _InfoRow(label: 'Colony', value: unit.colony),
        _InfoRow(label: 'Type', value: unit.type),
        const SizedBox(height: 20),
        if (allotment != null && allottee != null)
          AllottedUnitView(
            unitLabel: unit.displayLabel,
            allotment: allotment,
            allottee: allottee,
            payments: _payments,
            onRecordPayment: _openRecordPayment,
            onAllotteeModified: _load,
            onVacated: _handleVacated,
          )
        else if (isAdmin)
          AllotUnitForm(
            unitId: unit.id,
            unitLabel: unit.displayLabel,
            onAllotted: _handleAllotted,
          )
        else
          const _AdminOnlyNotice(
            message: 'This unit is vacant. Only an admin can allot it.',
          ),
      ],
    );
  }
}

class _AdminOnlyNotice extends StatelessWidget {
  final String message;
  const _AdminOnlyNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.vacantGray.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 18, color: AppColors.vacantGray),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.vacantGray)),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: AppColors.vacantGray)),
          ),
          Expanded(
            child: Text(
              value,
              style: monospace ? AppTheme.numericData.copyWith(fontSize: 16) : null,
            ),
          ),
        ],
      ),
    );
  }
}