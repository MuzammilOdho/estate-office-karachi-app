import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../repositories/payments_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/fiscal_year_utils.dart';
import '../utils/validators.dart';
import '../widgets/date_input_field.dart';

class RecordPaymentSheet extends StatefulWidget {
  final String allotmentId;
  final String unitLabel;
  final String allotteeName;
  const RecordPaymentSheet({
    super.key,
    required this.allotmentId,
    this.unitLabel = '',
    this.allotteeName = '',
  });

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _paymentsRepository = PaymentsRepository();
  final _imagePicker = ImagePicker();

  final _amountPaidController = TextEditingController();
  final _challanNoController = TextEditingController();
  final _remarksController = TextEditingController();

  DateTime? _date = DateTime.now();

  XFile? _capturedPhoto;
  bool _isCapturing = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountPaidController.dispose();
    _challanNoController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (photo != null && mounted) {
        setState(() => _capturedPhoto = photo);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
          "Couldn't open the camera. Check the app has camera permission and try again.";
        });
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final photo = _capturedPhoto;
    if (photo == null) {
      setState(() => _errorMessage = 'Photograph the challan slip before saving.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final bytes = await photo.readAsBytes();
      await _paymentsRepository.createPayment(
        allotmentId: widget.allotmentId,
        date: _date!,
        amountPaid: double.parse(_amountPaidController.text.trim()),
        challanNo: _challanNoController.text,
        remarks: _remarksController.text,
        imageBytes: bytes,
        imageFilename: 'challan_${DateTime.now().millisecondsSinceEpoch}.jpg',
        unitLabel: widget.unitLabel,
        allotteeName: widget.allotteeName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded.')),
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
    final fy = _date != null ? FiscalYearUtils.fyForDate(_date!) : null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
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
                Row(
                  children: [
                    Expanded(
                      child: Text('Add payment', style: Theme.of(context).textTheme.titleLarge),
                    ),
                    if (fy != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('FY $fy', style: AppTheme.numericData.copyWith(fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                DateInputField(
                  label: 'Date',
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  onChanged: (d) => setState(() => _date = d),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountPaidController,
                  decoration: const InputDecoration(labelText: 'Amount paid (Rs.)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTheme.numericData,
                  validator: (v) => Validators.positiveNumber(v, label: 'Amount paid'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _challanNoController,
                  decoration: const InputDecoration(labelText: 'Challan number'),
                  style: AppTheme.numericData,
                  validator: (v) => Validators.required(v, label: 'Challan number'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _remarksController,
                  decoration: const InputDecoration(labelText: 'Remarks (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                Text('Challan photo', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildPhotoCapture(),
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
                      : const Text('Save payment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCapture() {
    if (_capturedPhoto != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_capturedPhoto!.path),
              height: 220,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isCapturing ? null : _capturePhoto,
            icon: const Icon(Icons.replay_outlined),
            label: const Text('Retake photo'),
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: _isCapturing ? null : _capturePhoto,
      icon: _isCapturing
          ? const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : const Icon(Icons.camera_alt_outlined),
      label: Text(_isCapturing ? 'Opening camera…' : 'Photograph challan slip'),
    );
  }
}