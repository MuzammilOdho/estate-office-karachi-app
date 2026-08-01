import 'package:pocketbase/pocketbase.dart';

class AllotmentModel {
  final String id;
  final String unitId;
  final String allotteeId;
  final DateTime dateOfAllotment;
  final DateTime dateOfOccupation;
  final DateTime? dateOfVacancy;

  const AllotmentModel({
    required this.id,
    required this.unitId,
    required this.allotteeId,
    required this.dateOfAllotment,
    required this.dateOfOccupation,
    this.dateOfVacancy,
  });

  /// The single source of truth for "is this allotment current". No
  /// separate status field — an allotment is active exactly when it has
  /// no vacancy date. See AllotmentsRepository for why this replaced the
  /// old dual-status design.
  bool get isActive => dateOfVacancy == null;

  factory AllotmentModel.fromRecord(RecordModel record) {
    final rawAllotmentDate = record.get<String>('date_of_allotment', '');
    final rawOccupationDate = record.get<String>('date_of_occupation', '');
    final rawVacancyDate = record.get<String>('date_of_vacancy', '');

    return AllotmentModel(
      id: record.id,
      unitId: record.get<String>('unit', ''),
      allotteeId: record.get<String>('allottee', ''),
      dateOfAllotment: rawAllotmentDate.isEmpty
          ? DateTime.now()
          : DateTime.parse(rawAllotmentDate),
      dateOfOccupation: rawOccupationDate.isEmpty
          ? DateTime.now()
          : DateTime.parse(rawOccupationDate),
      dateOfVacancy:
      rawVacancyDate.isEmpty ? null : DateTime.parse(rawVacancyDate),
    );
  }
}