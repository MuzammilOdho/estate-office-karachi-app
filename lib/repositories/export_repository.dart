import 'dart:async';

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

  /// Pages through matching payments server-side (already sorted -date,
  /// so no client re-sort needed) and yields [ExportRow]s as they're
  /// resolved. Each page is fetched, display info resolved, then yielded
  /// and discarded — the caller never holds more than ~1 page of rows
  /// and ~1 page of allotments in memory, regardless of export size.
  ///
  /// The page size is generous (500) to keep page-count low; PocketBase
  /// internally batches the same way so this is just controlling how
  /// much we materialize at once.
  ///
  /// [onRowCount] is called after every page with a running total so the
  /// caller (ExportScreen) can show "Report generated with N payments."
  Stream<ExportRow> streamReport({
    required ExportScope scope,
    required ExportPeriod period,
    String? unitId,
    String? colony,
    String? fy,
    int? year,
    int? month,
    void Function(int)? onRowCount,
  }) async* {
    // Build the filter — same server-side filter logic as before.
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
        break;
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
        break;
    }

    final filter = filterParts.isEmpty
        ? null
        : _pb.filter(filterParts.join(' && '), filterParams);

    int runningCount = 0;
    int page = 1;
    bool hasMore = true;

    while (hasMore) {
      final paymentPage = await _pb.collection(Collections.payments).getList(
        page: page,
        perPage: 500,
        sort: '-date',
        filter: filter,
      );

      hasMore = paymentPage.page < paymentPage.totalPages;

      if (paymentPage.items.isEmpty) {
        if (runningCount == 0) return; // truly empty — caller shows "no payments"
        break; // last page was empty, stop
      }

      // Resolve display info for only the allotments on this page.
      // Same approach as before but scoped to one page.
      final allotmentIds = {
        for (final p in paymentPage.items) p.get<String>('allotment', ''),
      }..removeWhere((id) => id.isEmpty);

      if (allotmentIds.isEmpty) {
        // Orphaned payments with no allotment — skip entire page.
        page++;
        continue;
      }

      final idFilterParts = <String>[];
      final idFilterParams = <String, dynamic>{};
      var i = 0;
      for (final id in allotmentIds) {
        final key = 'id$i';
        idFilterParts.add('id = {:$key}');
        idFilterParams[key] = id;
        i++;
      }

      final allotmentRecords = await _pb
          .collection(Collections.allotments)
          .getFullList(
            filter: _pb.filter(idFilterParts.join(' || '), idFilterParams),
            expand: 'allottee,unit',
          );
      final allotmentById = {for (final a in allotmentRecords) a.id: a};

      for (final payment in paymentPage.items) {
        final allotmentRecord =
            allotmentById[payment.get<String>('allotment', '')];
        if (allotmentRecord == null) continue; // orphaned payment — skip

        final RecordModel? allotteeRecord =
            allotmentRecord.get<RecordModel?>('expand.allottee', null);
        final RecordModel? unitRecord =
            allotmentRecord.get<RecordModel?>('expand.unit', null);
        if (unitRecord == null) continue;

        final unit = UnitModel.fromRecord(unitRecord);
        final rawDobStr = allotteeRecord?.get<String>('dob', '') ?? '';
        final rawAllotmentDate =
            allotmentRecord.get<String>('date_of_allotment', '');
        final rawOccupationDate =
            allotmentRecord.get<String>('date_of_occupation', '');
        final rawPaymentDate = payment.get<String>('date', '');

        yield ExportRow(
          unitLabel: unit.displayLabel,
          type: unit.type,
          colony: unit.colony,
          allotteeName: allotteeRecord?.get<String>('name', '') ?? '',
          cnic: allotteeRecord?.get<String>('cnic', '') ?? '',
          designation: allotteeRecord?.get<String>('designation', '') ?? '',
          department: allotteeRecord?.get<String>('department', '') ?? '',
          dateOfAllotment: rawAllotmentDate.isEmpty
              ? DateTime.now()
              : DateTime.parse(rawAllotmentDate),
          dateOfOccupation: rawOccupationDate.isEmpty
              ? DateTime.now()
              : DateTime.parse(rawOccupationDate),
          dob: rawDobStr.isEmpty ? null : DateTime.parse(rawDobStr),
          paymentDate: rawPaymentDate.isEmpty
              ? DateTime.now()
              : DateTime.parse(rawPaymentDate),
          fy: payment.get<String>('fy', fy ?? ''),
          amountDue: payment.get<double>('amount_due', 0),
          amountRecovered: payment.get<double>('amount_paid', 0),
        );

        runningCount++;
      }

      onRowCount?.call(runningCount);
      page++;
    }
  }
}
