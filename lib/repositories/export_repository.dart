import 'package:pocketbase/pocketbase.dart';

import '../config/constants.dart';
import '../models/export_row.dart';
import '../models/unit_model.dart';
import '../services/pocketbase_service.dart';
import '../utils/app_exception.dart';
import '../utils/pocketbase_date_format.dart';

/// Which slice of the estate a report covers.
enum ExportScope { allUnits, colony, singleUnit }

/// Which time window a report covers. [allTime] is only offered for
/// [ExportScope.singleUnit] (a unit's "complete payment history").
enum ExportPeriod { fiscalYear, month, allTime }

class ExportRepository {
  PocketBase get _pb => PocketBaseService.instance.client;

  /// Builds report rows — one per payment — for the given [scope] +
  /// [period] combination. This single method backs all three report
  /// types you asked for:
  ///   - one unit's full history: scope=singleUnit, period=allTime/fiscalYear
  ///   - all units for a period:   scope=allUnits,  period=fiscalYear/month
  ///   - one colony for a period:  scope=colony,    period=fiscalYear/month
  ///
  /// The payments query itself is filtered at the database level (via
  /// PocketBase's relation-chain filters, e.g. `allotment.unit.colony = X`)
  /// rather than fetched in full and filtered client-side, so this stays
  /// fast even as the number of historical payments grows. Only the
  /// (much smaller) set of allotments actually referenced by the matching
  /// payments is then fetched, to resolve unit/allottee display info.
  Future<List<ExportRow>> buildReport({
    required ExportScope scope,
    required ExportPeriod period,
    String? unitId,
    String? colony,
    String? fy,
    int? year,
    int? month,
  }) async {
    try {
      final filterParts = <String>[];
      final filterParams = <String, dynamic>{};

      switch (period) {
        case ExportPeriod.fiscalYear:
          if (fy == null || fy.isEmpty) {
            throw const AppException('Choose a fiscal year.');
          }
          filterParts.add('fy = {:fy}');
          filterParams['fy'] = fy;
          break;
        case ExportPeriod.month:
          if (year == null || month == null) {
            throw const AppException('Choose a month.');
          }
          final start = DateTime(year, month, 1);
          final end = DateTime(year, month + 1, 1);
          filterParts.add('date >= {:start} && date < {:end}');
          filterParams['start'] = pbFilterDate(start);
          filterParams['end'] = pbFilterDate(end);
          break;
        case ExportPeriod.allTime:
          break; // no time filter
      }

      switch (scope) {
        case ExportScope.singleUnit:
          if (unitId == null || unitId.isEmpty) {
            throw const AppException('Choose a unit.');
          }
          filterParts.add('allotment.unit = {:unitId}');
          filterParams['unitId'] = unitId;
          break;
        case ExportScope.colony:
          if (colony == null || colony.isEmpty) {
            throw const AppException('Choose a colony.');
          }
          filterParts.add('allotment.unit.colony = {:colony}');
          filterParams['colony'] = colony;
          break;
        case ExportScope.allUnits:
          break; // no scope filter
      }

      final paymentRecords = await _pb.collection(Collections.payments).getFullList(
        filter: filterParts.isEmpty
            ? null
            : _pb.filter(filterParts.join(' && '), filterParams),
        sort: '-date',
      );

      if (paymentRecords.isEmpty) return [];

      // Resolve display info only for the allotments actually referenced
      // by the matching payments, not the whole estate's history.
      final allotmentIds = {
        for (final p in paymentRecords) p.get<String>('allotment', ''),
      }..removeWhere((id) => id.isEmpty);

      if (allotmentIds.isEmpty) return [];

      final idFilterParts = <String>[];
      final idFilterParams = <String, dynamic>{};
      var i = 0;
      for (final id in allotmentIds) {
        final key = 'id$i';
        idFilterParts.add('id = {:$key}');
        idFilterParams[key] = id;
        i++;
      }

      final allotmentRecords = await _pb.collection(Collections.allotments).getFullList(
        filter: _pb.filter(idFilterParts.join(' || '), idFilterParams),
        expand: 'allottee,unit',
      );
      final allotmentById = {for (final a in allotmentRecords) a.id: a};

      final rows = <ExportRow>[];
      for (final payment in paymentRecords) {
        final allotmentRecord = allotmentById[payment.get<String>('allotment', '')];
        if (allotmentRecord == null) continue; // orphaned payment — skip, don't crash

        final RecordModel? allotteeRecord =
        allotmentRecord.get<RecordModel>('expand.allottee', null);
        final RecordModel? unitRecord =
        allotmentRecord.get<RecordModel>('expand.unit', null);
        if (unitRecord == null) continue;

        final unit = UnitModel.fromRecord(unitRecord);
        final rawDobStr = allotteeRecord?.get<String>('dob', '') ?? '';
        final rawAllotmentDate =
        allotmentRecord.get<String>('date_of_allotment', '');
        final rawOccupationDate =
        allotmentRecord.get<String>('date_of_occupation', '');
        final rawPaymentDate = payment.get<String>('date', '');

        rows.add(ExportRow(
          unitLabel: unit.displayLabel,
          type: unit.type,
          colony: unit.colony,
          allotteeName: allotteeRecord?.get<String>('name', '') ?? '',
          cnic: allotteeRecord?.get<String>('cnic', '') ?? '',
          designation: allotteeRecord?.get<String>('designation', '') ?? '',
          department: allotteeRecord?.get<String>('department', '') ?? '',
          dateOfAllotment:
          rawAllotmentDate.isEmpty ? DateTime.now() : DateTime.parse(rawAllotmentDate),
          dateOfOccupation:
          rawOccupationDate.isEmpty ? DateTime.now() : DateTime.parse(rawOccupationDate),
          dob: rawDobStr.isEmpty ? null : DateTime.parse(rawDobStr),
          paymentDate: rawPaymentDate.isEmpty ? DateTime.now() : DateTime.parse(rawPaymentDate),
          fy: payment.get<String>('fy', fy ?? ''),
          amountDue: payment.get<double>('amount_due', 0),
          amountRecovered: payment.get<double>('amount_paid', 0),
        ));
      }

      // Most recent payment first, matching the payments query's own sort.
      rows.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
      return rows;
    } catch (e) {
      throw asAppException(e);
    }
  }
}