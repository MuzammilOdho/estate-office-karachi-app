import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/allottee_model.dart';
import '../repositories/allottee_modifications_repository.dart';
import '../repositories/allottees_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/input_formatters.dart';
import '../utils/validators.dart';
import '../widgets/date_input_field.dart';
import '../widgets/document_picker.dart';

class ModifyAllotteeSheet extends StatefulWidget {
  final AllotteeModel allottee;
  const ModifyAllotteeSheet({super.key, required this.allottee});

  @override
  State<ModifyAllotteeSheet> createState() => _ModifyAllotteeSheetState();
}

class _ModifyAllotteeSheetState extends State<ModifyAllotteeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _modificationsRepository = AllotteeModificationsRepository();
  final _allotteesRepository = AllotteesRepository();
  final _documentPickerKey = GlobalKey<DocumentPickerState>();

  late final _nameController = TextEditingController(text: widget.allottee.name);
  late final _cnicController = TextEditingController(text: widget.allottee.cnic);
  late final _designationController =
  TextEditingController(text: widget.allottee.designation);
  late final _departmentController =
  TextEditingController(text: widget.allottee.department);
  late final _bsController = TextEditingController(text: widget.allottee.bs);
  late final _personalNoController =
  TextEditingController(text: widget.allottee.personalNo);
  late final _phoneController =
  TextEditingController(text: widget.allottee.phone);
  late DateTime? _dob = widget.allottee.dob;

  final _remarksController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void dispose() {
    _nameController.dispose();
    _cnicController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _bsController.dispose();
    _personalNoController.dispose();
    _phoneController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  String _dobDisplay(DateTime? d) => d == null ? '' : _dateFormat.format(d);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final documents = _documentPickerKey.currentState?.documents ?? [];
    if (documents.isEmpty) {
      setState(() {
        _errorMessage = 'Attach at least one supporting document before saving.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final original = widget.allottee;

      // Duplicate prevention: check CNIC, personal_no, phone (exclude self).
      for (final entry in [
        MapEntry('cnic', _cnicController.text),
        MapEntry('personal_no', _personalNoController.text),
        MapEntry('phone', _phoneController.text),
      ]) {
        final conflict = await _allotteesRepository.findByExactField(
          field: entry.key,
          value: entry.value,
          excludeId: original.id,
        );
        if (conflict != null) {
          final label = entry.key == 'cnic'
              ? 'CNIC'
              : entry.key == 'personal_no'
                  ? 'Personal No'
                  : 'Phone No';
          if (!mounted) return;
          setState(() {
            _errorMessage = '$label already exists (used by "$conflict").';
          });
          return;
        }
      }

      final edits = [
        AllotteeFieldEdit(
          label: 'Name',
          oldValue: original.name,
          newValue: _nameController.text.trim(),
        ),
        AllotteeFieldEdit(
          label: 'CNIC',
          oldValue: original.cnic,
          newValue: _cnicController.text.trim(),
        ),
        AllotteeFieldEdit(
          label: 'Designation',
          oldValue: original.designation,
          newValue: _designationController.text.trim(),
        ),
        AllotteeFieldEdit(
          label: 'Department',
          oldValue: original.department,
          newValue: _departmentController.text.trim(),
        ),
        AllotteeFieldEdit(
          label: 'BS',
          oldValue: original.bs,
          newValue: _bsController.text.trim(),
        ),
        AllotteeFieldEdit(
          label: 'Personal No',
          oldValue: original.personalNo,
          newValue: _personalNoController.text.trim(),
        ),
        AllotteeFieldEdit(
          label: 'Mobile No',
          oldValue: original.phone,
          newValue: _phoneController.text.trim(),
        ),
        AllotteeFieldEdit(
          label: 'Date of birth',
          oldValue: _dobDisplay(original.dob),
          newValue: _dobDisplay(_dob),
        ),
      ];

      final updateBody = {
        'name': _nameController.text.trim(),
        'cnic': _cnicController.text.trim(),
        'designation': _designationController.text.trim(),
        'department': _departmentController.text.trim(),
        'bs': _bsController.text.trim(),
        'personal_no': _personalNoController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dob': _dob?.toIso8601String() ?? '',
      };

      final documentBytesList = <List<int>>[];
      final documentFilenames = <String>[];
      for (var i = 0; i < documents.length; i++) {
        documentBytesList.add(await documents[i].readAsBytes());
        documentFilenames.add('doc_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
      }

      await _modificationsRepository.submitModification(
        allotteeId: original.id,
        edits: edits,
        updateBody: updateBody,
        remarks: _remarksController.text,
        documentBytesList: documentBytesList,
        documentFilenames: documentFilenames,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Allottee info updated.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is AppException ? e.message : 'Something went wrong.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
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
                Text('Modify allottee info', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                const Text(
                  'Changes are recorded with your name and the date, along with '
                      'the documents you attach below.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cnicController,
                  decoration: const InputDecoration(
                    labelText: 'CNIC',
                    hintText: '42101-1234567-1',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [CnicInputFormatter()],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.length != 13) return 'CNIC must have 13 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _designationController,
                  decoration: const InputDecoration(labelText: 'Designation'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _departmentController,
                  decoration: const InputDecoration(labelText: 'Department'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bsController,
                  decoration: const InputDecoration(labelText: 'BS (basic scale)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _personalNoController,
                  decoration: const InputDecoration(labelText: 'Personal No'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Mobile No',
                    hintText: '0300-1234567',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [PhoneInputFormatter()],
                  validator: Validators.phone,
                ),
                const SizedBox(height: 12),
                DateInputField(
                  label: 'Date of birth',
                  initialDate: _dob,
                  firstDate: DateTime(1930),
                  lastDate: DateTime.now(),
                  required: false,
                  onChanged: (d) => setState(() => _dob = d),
                ),
                const SizedBox(height: 20),
                Text('Supporting documents', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                DocumentPicker(key: _documentPickerKey),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _remarksController,
                  decoration: const InputDecoration(labelText: 'Remarks (optional)'),
                  maxLines: 2,
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
                      : const Text('Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}