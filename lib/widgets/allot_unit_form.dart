import 'package:flutter/material.dart';

import '../repositories/allotments_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import 'allottee_picker.dart';
import 'date_input_field.dart';

class AllotUnitForm extends StatefulWidget {
  final String unitId;
  final String unitLabel;
  final VoidCallback onAllotted;

  const AllotUnitForm({
    super.key,
    required this.unitId,
    required this.unitLabel,
    required this.onAllotted,
  });

  @override
  State<AllotUnitForm> createState() => _AllotUnitFormState();
}

class _AllotUnitFormState extends State<AllotUnitForm> {
  final _formKey = GlobalKey<FormState>();
  final _allotmentsRepository = AllotmentsRepository();
  final _allotteePickerKey = GlobalKey<AllotteePickerState>();

  DateTime? _dateOfAllotment = DateTime.now();
  DateTime? _dateOfOccupation = DateTime.now();

  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final pickerState = _allotteePickerKey.currentState;
      final allotteeId = await pickerState?.resolveAllotteeId();
      if (allotteeId == null) {
        // AllotteePicker already shows its own inline error in this case.
        return;
      }

      await _allotmentsRepository.allotUnit(
        unitId: widget.unitId,
        allotteeId: allotteeId,
        dateOfAllotment: _dateOfAllotment!,
        dateOfOccupation: _dateOfOccupation!,
        unitLabel: widget.unitLabel,
        allotteeName: pickerState?.resolvedDisplayName ?? '',
      );
      if (!mounted) return;
      widget.onAllotted();
    } catch (e) {
      setState(() {
        _errorMessage = e is AppException ? e.message : 'Something went wrong.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Allot this unit', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          AllotteePicker(key: _allotteePickerKey),
          const SizedBox(height: 16),
          DateInputField(
            label: 'Date of allotment',
            initialDate: _dateOfAllotment,
            firstDate: DateTime(2000),
            lastDate: now.add(const Duration(days: 1)),
            onChanged: (d) => setState(() => _dateOfAllotment = d),
          ),
          const SizedBox(height: 12),
          DateInputField(
            label: 'Date of occupation',
            initialDate: _dateOfOccupation,
            firstDate: DateTime(2000),
            lastDate: now.add(const Duration(days: 1)),
            onChanged: (d) => setState(() => _dateOfOccupation = d),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(_errorMessage!, style: const TextStyle(color: AppColors.dueRed)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Text('Allot unit'),
          ),
        ],
      ),
    );
  }
}