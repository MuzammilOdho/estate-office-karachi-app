import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/input_formatters.dart';

/// A date field that can be filled in two ways — typed directly (with
/// live dd-mm-yyyy formatting and validation) or picked from the native
/// calendar via the trailing icon, which fills in the same text field.
/// Participates in the ambient Form's validation like any other
/// TextFormField.
class DateInputField extends StatefulWidget {
  final String label;
  final DateTime? initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool required;
  final ValueChanged<DateTime?> onChanged;

  const DateInputField({
    super.key,
    required this.label,
    this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.required = true,
    required this.onChanged,
  });

  @override
  State<DateInputField> createState() => _DateInputFieldState();
}

class _DateInputFieldState extends State<DateInputField> {
  static final _format = DateFormat('dd-MM-yyyy');

  late final _controller = TextEditingController(
    text: widget.initialDate == null ? '' : _format.format(widget.initialDate!),
  );

  DateTime? _tryParse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    try {
      return _format.parseStrict(trimmed);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tryParse(_controller.text) ?? widget.initialDate ?? DateTime.now(),
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (picked != null) {
      if (!mounted) return;
      _controller.text = _format.format(picked);
      widget.onChanged(picked);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [DateInputFormatter()],
      decoration: InputDecoration(
        labelText: widget.required ? widget.label : '${widget.label} (optional)',
        hintText: 'dd-mm-yyyy',
        prefixIcon: const Icon(Icons.calendar_today_outlined),
        suffixIcon: IconButton(
          icon: const Icon(Icons.date_range_outlined),
          tooltip: 'Pick a date',
          onPressed: _openPicker,
        ),
      ),
      onChanged: (value) => widget.onChanged(_tryParse(value)),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) {
          return widget.required ? '${widget.label} is required' : null;
        }
        final parsed = _tryParse(text);
        if (parsed == null) return 'Enter a valid date (dd-mm-yyyy)';
        if (parsed.isBefore(widget.firstDate) || parsed.isAfter(widget.lastDate)) {
          return 'Date is out of range';
        }
        return null;
      },
    );
  }
}