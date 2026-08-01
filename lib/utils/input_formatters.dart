import 'package:flutter/services.dart';

/// Formats CNIC input live as the person types: 42101-1234567-1.
/// Strips anything that isn't a digit and caps at 13 digits.
class CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final capped = digits.length > 13 ? digits.substring(0, 13) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      buffer.write(capped[i]);
      if (i == 4 || i == 11) buffer.write('-');
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formats date input live as the person types: dd-mm-yyyy. Strips
/// anything that isn't a digit and caps at 8 digits.
class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final capped = digits.length > 8 ? digits.substring(0, 8) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      buffer.write(capped[i]);
      if (i == 1 || i == 3) buffer.write('-');
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}