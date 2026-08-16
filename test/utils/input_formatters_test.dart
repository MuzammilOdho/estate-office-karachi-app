import 'package:estate_registry/utils/input_formatters.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Convenience: format an edit from [oldText] → [newText] with the caret at
/// [caret] in the *new* value, and return (text, caret) of the result.
({String text, int caret}) _format(
  TextInputFormatter formatter,
  String oldText,
  String newText, {
  int? caret,
}) {
  final newCaret = caret ?? newText.length;
  final oldValue = TextEditingValue(
    text: oldText,
    selection: TextSelection.collapsed(offset: oldText.length),
  );
  final newValue = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: newCaret),
  );
  final result = formatter.formatEditUpdate(oldValue, newValue);
  return (text: result.text, caret: result.selection.baseOffset);
}

void main() {
  group('CnicInputFormatter', () {
    final f = CnicInputFormatter();

    test('formats digits as 42101-1234567-1', () {
      final r = _format(f, '', '4210112345671');
      expect(r.text, '42101-1234567-1');
    });

    test('caps at 13 digits', () {
      final r = _format(f, '', '4210112345671999');
      expect(r.text, '42101-1234567-1');
    });

    test('strips non-digits from paste', () {
      final r = _format(f, '', '42101-1234567-1');
      expect(r.text, '42101-1234567-1');
    });

    test('partial input: 5 digits → 42101-', () {
      final r = _format(f, '', '42101');
      expect(r.text, '42101-');
    });

    test('partial input: 12 digits → 42101-1234567-', () {
      final r = _format(f, '', '421011234567');
      expect(r.text, '42101-1234567-');
    });

    test('forward typing keeps caret at end', () {
      // Type '4' then '2' (append).
      var r = _format(f, '', '4');
      expect(r.caret, 1);
      r = _format(f, '4', '42');
      expect(r.caret, 2);
    });
  });

  group('DateInputFormatter', () {
    final f = DateInputFormatter();

    test('formats 8 digits as dd-mm-yyyy', () {
      final r = _format(f, '', '01082025');
      expect(r.text, '01-08-2025');
    });

    test('caps at 8 digits', () {
      final r = _format(f, '', '01082025999');
      expect(r.text, '01-08-2025');
    });

    test('partial: 2 digits → 01-', () {
      final r = _format(f, '', '01');
      expect(r.text, '01-');
    });

    test('partial: 4 digits → 01-08-', () {
      final r = _format(f, '', '0108');
      expect(r.text, '01-08-');
    });

    test('strips letters', () {
      final r = _format(f, '', '01a08b2025');
      expect(r.text, '01-08-2025');
    });
  });

  group('PhoneInputFormatter', () {
    final f = PhoneInputFormatter();

    test('formats 11 digits as 0300-1234567', () {
      final r = _format(f, '', '03001234567');
      expect(r.text, '0300-1234567');
    });

    test('caps at 11 digits', () {
      final r = _format(f, '', '03001234567999999');
      expect(r.text, '0300-1234567');
    });

    test('partial: 4 digits → 0300-', () {
      final r = _format(f, '', '0300');
      expect(r.text, '0300-');
    });

    test('partial: 3 digits → 030 (no separator yet)', () {
      final r = _format(f, '', '030');
      expect(r.text, '030');
    });
  });

  group('Caret positioning (mid-string edit)', () {
    final f = CnicInputFormatter();

    test('editing in the middle does not jump caret to end', () {
      // Start with a complete CNIC, caret in the middle after the 2nd digit.
      const oldText = '42101-1234567-1';
      // Simulate inserting a digit in the middle: change '42101...' to
      // '42X101...' by replacing — but since we strip, let's simulate a
      // backspace of one middle digit instead.
      //
      // Old text '42101-1234567-1' (15 chars). Caret at position 3 (after
      // '421'). User deletes the '1' at index 2 → new text '4201-1234567-1'
      // but caret was at 3. After reformat the digits are '420112345671'
      // (12 digits) → '42011-2345671'. The caret should land after the same
      // logical number of digits (2) that preceded it, NOT at the end.
      const oldVal = TextEditingValue(
        text: oldText,
        selection: TextSelection.collapsed(offset: 3),
      );
      const newVal = TextEditingValue(
        text: '4201-1234567-1',
        selection: TextSelection.collapsed(offset: 3),
      );
      final result = f.formatEditUpdate(oldVal, newVal);
      // 3 digits preceded the caret (old '421'), so caret should be after
      // 3 digits in the new formatted string. New text starts '4201-1...'
      // so after 3 digits ('420') = position 3.
      expect(result.selection.baseOffset, lessThan(result.text.length));
      expect(result.selection.baseOffset, 3);
    });

    test('forward typing at end snaps caret to end', () {
      const oldText = '42101-1234567-';
      const newText = '42101-1234567-1';
      const oldVal = TextEditingValue(
        text: oldText,
        selection: TextSelection.collapsed(offset: oldText.length),
      );
      const newVal = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
      final result = f.formatEditUpdate(oldVal, newVal);
      expect(result.selection.baseOffset, result.text.length);
    });
  });
}
