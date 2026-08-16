import 'package:flutter/services.dart';

/// Helpers shared by the formatters below. The core problem all three
/// solve: we want to live-format structured input (CNIC, dates, phone),
/// but the naive "strip non-digits, rebuild, set caret to end" approach
/// breaks two common interactions:
///
///  1. Editing in the middle of the field — the caret jumps to the end.
///  2. Backspacing across an inserted separator — the separator keeps
///     reappearing because the digit count didn't change.
///
/// Fix: only force the caret to the end when the user was already typing
/// at the end (forward typing / append). In every other case, map the
/// caret through the reformat so it lands on the same logical digit.
class _FormatHelper {
  _FormatHelper._();

  /// Rebuilds a [TextEditingValue] from the stripped [digits], inserting
  /// [separator] after the character positions in [separatorAfterIndices]
  /// (zero-based indices into the *digit* string), capping at [maxDigits].
  ///
  /// Caret placement:
  ///  - If the user was typing at the end (old caret == old text length
  ///    and new digits >= old digits), keep caret at end — matches what
  ///    every phone-number field does while typing forward.
  ///  - Otherwise, count how many digits were before the old caret and
  ///    place the new caret just after that many digits (+ the separators
  ///    that precede it), so the caret tracks the same logical position.
  static TextEditingValue build({
    required TextEditingValue oldValue,
    required TextEditingValue newValue,
    required String digits,
    required int maxDigits,
    required List<int> separatorAfterIndices,
  }) {
    final capped = digits.length > maxDigits
        ? digits.substring(0, maxDigits)
        : digits;

    final buffer = StringBuffer();
    final separatorSet = separatorAfterIndices.toSet();
    for (var i = 0; i < capped.length; i++) {
      buffer.write(capped[i]);
      if (separatorSet.contains(i)) buffer.write('-');
    }
    final formatted = buffer.toString();

    // Decide caret position.
    final oldText = oldValue.text;
    final oldCaret = oldValue.selection.baseOffset.clamp(0, oldText.length);
    final wasAtEnd = oldCaret == oldText.length;
    final oldDigits = oldText.replaceAll(RegExp(r'[^0-9]'), '');
    final grew = capped.length >= oldDigits.length;

    int caret;
    if (wasAtEnd && grew) {
      // Forward typing at the end — snap to end (standard UX).
      caret = formatted.length;
    } else {
      // Editing in the middle / deleting — preserve digit-relative position.
      final digitsBeforeCaret =
          oldText.substring(0, oldCaret).replaceAll(RegExp(r'[^0-9]'), '').length;
      // Walk the formatted string, counting separators before the target digit.
      var digitCount = 0;
      caret = 0;
      for (var i = 0; i < formatted.length; i++) {
        if (digitCount == digitsBeforeCaret) {
          caret = i;
          break;
        }
        final ch = formatted[i];
        if (RegExp(r'[0-9]').hasMatch(ch)) {
          digitCount++;
        }
        caret = i + 1;
      }
      if (caret > formatted.length) caret = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}

/// Formats CNIC input live as the person types: 42101-1234567-1.
/// Strips anything that isn't a digit and caps at 13 digits.
class CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    return _FormatHelper.build(
      oldValue: oldValue,
      newValue: newValue,
      digits: digits,
      maxDigits: 13,
      separatorAfterIndices: const [4, 11],
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
    return _FormatHelper.build(
      oldValue: oldValue,
      newValue: newValue,
      digits: digits,
      maxDigits: 8,
      separatorAfterIndices: const [1, 3],
    );
  }
}

/// Formats Pakistan mobile input live as the person types: 0300-1234567.
/// Strips anything that isn't a digit and caps at 11 digits.
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    return _FormatHelper.build(
      oldValue: oldValue,
      newValue: newValue,
      digits: digits,
      maxDigits: 11,
      separatorAfterIndices: const [3],
    );
  }
}
