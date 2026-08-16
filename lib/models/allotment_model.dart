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
    return AllotmentModel(
      id: record.id,
      unitId: record.get<String>('unit', ''),
      allotteeId: record.get<String>('allottee', ''),
      // `date_of_allotment` / `date_of_occupation` are optional on the
      // collection and may be empty or malformed in historical/imported
      // records. DateTime.parse throws FormatException on bad input,
      // which would crash the whole screen — parse defensively and fall
      // back to the record's `created` timestamp (always present), so a
      // single bad date never takes down the list.
      dateOfAllotment: _parseDate(
              record.get<String>('date_of_allotment', '')) ??
          _parseDate(record.get<String>('created', '')) ??
          DateTime.now(),
      dateOfOccupation: _parseDate(
              record.get<String>('date_of_occupation', '')) ??
          _parseDate(record.get<String>('created', '')) ??
          DateTime.now(),
      dateOfVacancy: _parseDate(record.get<String>('date_of_vacancy', '')),
    );
  }

  static DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}