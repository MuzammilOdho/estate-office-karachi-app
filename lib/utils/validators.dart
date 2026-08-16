class Validators {
  Validators._();

  static String? required(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  /// CNIC is optional (a lot of historical records don't have one on file
  /// yet) — if provided, it must look like a real CNIC.
  static String? cnic(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length != 13) {
      return 'CNIC must have 13 digits (e.g. 42101-1234567-1)';
    }
    return null;
  }

  /// Phone is optional — if provided, it must be a valid Pakistan mobile
  /// number (11 digits starting with 03).
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length != 11 || !digitsOnly.startsWith('03')) {
      return 'Enter a valid mobile no (e.g. 0300-1234567)';
    }
    return null;
  }

  static String? positiveNumber(String? value, {String label = 'Amount'}) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    final n = double.tryParse(value.trim());
    if (n == null) return '$label must be a number';
    if (n <= 0) return '$label must be greater than zero';
    return null;
  }
}