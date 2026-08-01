/// One row of an exported report — one row per payment, formatted to
/// match the office's existing paper/Excel register layout: unit and
/// occupant details repeated on every row, followed by the payment's
/// date (split into Date/Month/Year, matching the register) and its
/// Amount Due / Amount Recovered / Balance.
class ExportRow {
  final String unitLabel; // combined "Flat No./Quarter/House No." field
  final String type;
  final String colony; // "Location" in the register
  final String allotteeName;
  final String cnic;
  final String designation;
  final String department;
  final DateTime dateOfAllotment;
  final DateTime dateOfOccupation;
  final DateTime? dob;
  final DateTime paymentDate;
  final String fy;
  final double amountDue;
  final double amountRecovered;

  const ExportRow({
    required this.unitLabel,
    required this.type,
    required this.colony,
    required this.allotteeName,
    required this.cnic,
    required this.designation,
    required this.department,
    required this.dateOfAllotment,
    required this.dateOfOccupation,
    this.dob,
    required this.paymentDate,
    required this.fy,
    required this.amountDue,
    required this.amountRecovered,
  });

  /// Amount Due minus Amount Recovered, for this payment only — not a
  /// running/cumulative arrears balance across periods, since neither
  /// PocketBase nor this app currently tracks a carried-forward balance.
  double get balance => amountDue - amountRecovered;
}