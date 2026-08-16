import 'package:pocketbase/pocketbase.dart';

import '../config/constants.dart';

class AllotteeModel {
  final String id;
  final String name;
  final String cnic;
  final String designation;
  final String department;
  final String bs; // Basic (Pay) Scale — free text, e.g. "17", "-"
  final String personalNo; // Government service / personal number
  final String phone; // Mobile number, e.g. "0300-1234567"
  final DateTime? dob;

  const AllotteeModel({
    required this.id,
    required this.name,
    required this.cnic,
    required this.designation,
    required this.department,
    required this.bs,
    this.personalNo = '',
    this.phone = '',
    this.dob,
  });

  /// Age in whole years as of today — computed, never stored. Null when
  /// DOB isn't on record yet (common in imported historical data).
  int? get ageYears {
    final d = dob;
    if (d == null) return null;
    final now = DateTime.now();
    var age = now.year - d.year;
    final hasHadBirthdayThisYear =
        now.month > d.month || (now.month == d.month && now.day >= d.day);
    if (!hasHadBirthdayThisYear) age--;
    return age;
  }

  /// "retired" once strictly over the retirement age (spec: age > 60).
  /// Null (unknown) when DOB isn't on record.
  bool? get isRetired {
    final age = ageYears;
    if (age == null) return null;
    return age > AppDefaults.retirementAge;
  }

  String get serviceStatusLabel {
    final retired = isRetired;
    if (retired == null) return 'Unknown';
    return retired ? 'Retired' : 'In-service';
  }

  /// Auto-calculated retirement date: DOB + [retirementAge] years.
  /// Null when DOB isn't on record.
  ///
  /// Handles the Feb 29 edge case: if the DOB is a leap day and the
  /// retirement year isn't a leap year, normalize to Feb 28 instead of
  /// letting Dart's `DateTime` silently roll over to Mar 1.
  DateTime? get dateOfRetirement {
    final d = dob;
    if (d == null) return null;
    final targetYear = d.year + AppDefaults.retirementAge;
    // Only Feb 29 needs adjustment, and only when the target year isn't
    // itself a leap year.
    if (d.month == 2 && d.day == 29 && !_isLeapYear(targetYear)) {
      return DateTime(targetYear, 2, 28);
    }
    return DateTime(targetYear, d.month, d.day);
  }

  static bool _isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  factory AllotteeModel.fromRecord(RecordModel record) {
    final rawDob = record.get<String>('dob', '');
    return AllotteeModel(
      id: record.id,
      name: record.get<String>('name', ''),
      cnic: record.get<String>('cnic', ''),
      designation: record.get<String>('designation', ''),
      department: record.get<String>('department', ''),
      bs: record.get<String>('bs', ''),
      personalNo: record.get<String>('personal_no', ''),
      phone: record.get<String>('phone', ''),
      dob: DateTime.tryParse(rawDob),
    );
  }
}