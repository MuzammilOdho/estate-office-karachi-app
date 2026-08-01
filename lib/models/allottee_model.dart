import 'package:pocketbase/pocketbase.dart';

import '../config/constants.dart';

class AllotteeModel {
  final String id;
  final String name;
  final String cnic;
  final String designation;
  final String department;
  final String bs; // Basic (Pay) Scale — free text, e.g. "17", "-"
  final DateTime? dob;

  const AllotteeModel({
    required this.id,
    required this.name,
    required this.cnic,
    required this.designation,
    required this.department,
    required this.bs,
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

  factory AllotteeModel.fromRecord(RecordModel record) {
    final rawDob = record.get<String>('dob', '');
    return AllotteeModel(
      id: record.id,
      name: record.get<String>('name', ''),
      cnic: record.get<String>('cnic', ''),
      designation: record.get<String>('designation', ''),
      department: record.get<String>('department', ''),
      bs: record.get<String>('bs', ''),
      dob: rawDob.isEmpty ? null : DateTime.parse(rawDob),
    );
  }
}