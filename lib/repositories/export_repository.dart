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

  /// Maximum records per paginated request. PocketBase default max is 500.
  static const _perPage = 500;

  /// Yields [ExportRow]s grouped by unit → allotment. All payments for one
  /// allotment are consecutive (sorted by date ascending), followed by the
  /// next allotment. Allotments with zero payments still produce one row
  /// with blank payment columns. Vacant units (no allotments) produce one
  /// row with blank allottee + payment columns.
  ///
  /// Performance: 3-phase batch approach — no N+1 queries.
  ///   Phase 1: Fetch all units (scope-filtered, paginated).
  ///   Phase 2: Fetch all allotments (scope-filtered, active + vacated, expand, paginated).
  ///   Phase 3: Fetch all payments (scope + period filtered, paginated).
  ///   Then: group payments by allotmentId client-side, walk units → allotments → payments.
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
    // --- Validate scope parameters ---
    switch (scope) {
      case ExportScope.singleUnit:
        if (unitId == null || unitId.isEmpty) {
          throw const AppException('Choose a unit.');
        }
      case ExportScope.colony:
        if (colony == null || colony.isEmpty) {
          throw const AppException('Choose a colony.');
        }
      case ExportScope.allUnits:
        break;
    }

    // --- Phase 1: Fetch all scope-matching units ---
    final units = await _fetchUnits(scope, unitId, colony);

    // --- Phase 2: Fetch all allotments (active + vacated) ---
    final allotmentRecords = await _fetchAllotments(scope, unitId, colony);

    // Group allotments by unitId for fast lookup.
    final allotmentsByUnit = <String, List<RecordModel>>{};
    for (final a in allotmentRecords) {
      final uid = a.get<String>('unit', '');
      allotmentsByUnit.putIfAbsent(uid, () => []).add(a);
    }

    // --- Phase 3: Fetch all period-filtered payments ---
    String? paymentFilter = _buildPaymentFilter(period, fy, year, month);
    final paymentRecords = await _fetchPayments(scope, unitId, colony, paymentFilter);

    // Group payments by allotmentId for fast lookup.
    final paymentsByAllotment = <String, List<RecordModel>>{};
    for (final p in paymentRecords) {
      final aid = p.get<String>('allotment', '');
      paymentsByAllotment.putIfAbsent(aid, () => []).add(p);
    }

    // --- Yield rows: walk units in sorted order ---
    int runningCount = 0;

    for (final unitRec in units) {
      final unit = UnitModel.fromRecord(unitRec);
      final unitAllotments = allotmentsByUnit[unitRec.id];

      if (unitAllotments == null || unitAllotments.isEmpty) {
        // Vacant unit — one row with blank allottee + payment columns.
        yield ExportRow(
          type: unit.type,
          houseNo: unit.houseNo,
          block: unit.block,
          flatNo: unit.flatNo,
          colony: unit.colony,
          personalNo: '',
          allotteeName: '',
          designation: '',
          bs: '',
          department: '',
          cnic: '',
        );
        runningCount++;
        onRowCount?.call(runningCount);
        continue;
      }

      // Sort allotments by date_of_allotment ascending for consistent ordering.
      unitAllotments.sort((a, b) {
        final da = a.get<String>('date_of_allotment', '');
        final db = b.get<String>('date_of_allotment', '');
        return da.compareTo(db);
      });

      for (final allotmentRec in unitAllotments) {
        final allotteeRec =
            allotmentRec.get<RecordModel?>('expand.allottee', null);

        final allotteeName = allotteeRec?.get<String>('name', '') ?? '';
        final cnic = allotteeRec?.get<String>('cnic', '') ?? '';
        final designation = allotteeRec?.get<String>('designation', '') ?? '';
        final bs = allotteeRec?.get<String>('bs', '') ?? '';
        final department = allotteeRec?.get<String>('department', '') ?? '';
        final personalNo = allotteeRec?.get<String>('personal_no', '') ?? '';
        final rawDob = allotteeRec?.get<String>('dob', '') ?? '';
        final dob = DateTime.tryParse(rawDob);

        DateTime? dateOfRetirement;
        if (dob != null) {
          // Same Feb-29 normalization as AllotteeModel.dateOfRetirement —
          // without it, a leap-day DOB silently rolls to Mar 1 in a
          // non-leap retirement year.
          final targetYear = dob.year + AppDefaults.retirementAge;
          if (dob.month == 2 && dob.day == 29 && !_isLeapYear(targetYear)) {
            dateOfRetirement = DateTime(targetYear, 2, 28);
          } else {
            dateOfRetirement = DateTime(targetYear, dob.month, dob.day);
          }
        }

        final rawAllotmentDate =
            allotmentRec.get<String>('date_of_allotment', '');
        final rawOccupationDate =
            allotmentRec.get<String>('date_of_occupation', '');
        // Nullable — an allotment with missing dates gets blank columns in
        // the CSV, NOT today's date.
        final dateOfAllotment = DateTime.tryParse(rawAllotmentDate);
        final dateOfOccupation = DateTime.tryParse(rawOccupationDate);

        // Get payments for this allotment (already sorted by date asc).
        final allotmentPayments = paymentsByAllotment[allotmentRec.id];

        if (allotmentPayments == null || allotmentPayments.isEmpty) {
          // Allotment with zero payments — one row with blank payment columns.
          yield ExportRow(
            type: unit.type,
            houseNo: unit.houseNo,
            block: unit.block,
            flatNo: unit.flatNo,
            colony: unit.colony,
            personalNo: personalNo,
            allotteeName: allotteeName,
            designation: designation,
            bs: bs,
            department: department,
            cnic: cnic,
            dateOfOccupation: dateOfOccupation,
            dateOfAllotment: dateOfAllotment,
            dob: dob,
            dateOfRetirement: dateOfRetirement,
          );
          runningCount++;
          onRowCount?.call(runningCount);
        } else {
          // One row per payment.
          for (final payment in allotmentPayments) {
            final rawPaymentDate = payment.get<String>('date', '');

            yield ExportRow(
              type: unit.type,
              houseNo: unit.houseNo,
              block: unit.block,
              flatNo: unit.flatNo,
              colony: unit.colony,
              personalNo: personalNo,
              allotteeName: allotteeName,
              designation: designation,
              bs: bs,
              department: department,
              cnic: cnic,
              dateOfOccupation: dateOfOccupation,
              dateOfAllotment: dateOfAllotment,
              dob: dob,
              dateOfRetirement: dateOfRetirement,
              paymentDate: DateTime.tryParse(rawPaymentDate),
              amountRecovered: payment.get<double>('amount_paid', 0),
              remarks: payment.get<String>('remarks', ''),
            );
            runningCount++;
            onRowCount?.call(runningCount);
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Phase fetchers (paginated)
  // ---------------------------------------------------------------------------

  /// Fetches all units matching the scope filter, paginated, sorted by
  /// colony → house_no → block → flat_no.
  Future<List<RecordModel>> _fetchUnits(
    ExportScope scope,
    String? unitId,
    String? colony,
  ) async {
    try {
      String filter;
      switch (scope) {
        case ExportScope.singleUnit:
          filter = _pb.filter('id = {:id}', {'id': unitId!});
        case ExportScope.colony:
          filter = _pb.filter('colony = {:colony}', {'colony': colony!});
        case ExportScope.allUnits:
          filter = ''; // no filter — fetch all units
      }

      return await _paginatedGet(
        collection: Collections.units,
        filter: filter.isEmpty ? null : filter,
        sort: 'colony, house_no, block, flat_no',
      );
    } catch (e) {
      throw asAppException(e);
    }
  }

  /// Fetches all allotments matching the scope filter (active + vacated),
  /// with expanded allottee + unit records.
  Future<List<RecordModel>> _fetchAllotments(
    ExportScope scope,
    String? unitId,
    String? colony,
  ) async {
    try {
      String filter;
      switch (scope) {
        case ExportScope.singleUnit:
          filter = _pb.filter('unit = {:unitId}', {'unitId': unitId!});
        case ExportScope.colony:
          filter = _pb.filter('unit.colony = {:colony}', {'colony': colony!});
        case ExportScope.allUnits:
          filter = ''; // no filter — fetch all allotments
      }

      return await _paginatedGet(
        collection: Collections.allotments,
        filter: filter.isEmpty ? null : filter,
        expand: 'allottee',
      );
    } catch (e) {
      throw asAppException(e);
    }
  }

  /// Fetches all payments matching scope + period filters, paginated,
  /// sorted by date ascending. Returns empty list if no period filter and
  /// scope is allUnits (would be too many records without a period gate).
  Future<List<RecordModel>> _fetchPayments(
    ExportScope scope,
    String? unitId,
    String? colony,
    String? paymentFilter,
  ) async {
    // For "allTime" + "allUnits" scope, fetching ALL payments across the
    // entire estate is likely too large. In this case we skip payments
    // entirely — every allotment gets a blank-payment row.
    if (paymentFilter == null && scope == ExportScope.allUnits) {
      return [];
    }

    try {
      final parts = <String>[];
      final params = <String, dynamic>{};

      switch (scope) {
        case ExportScope.singleUnit:
          parts.add('allotment.unit = {:unitId}');
          params['unitId'] = unitId!;
        case ExportScope.colony:
          parts.add('allotment.unit.colony = {:colony}');
          params['colony'] = colony!;
        case ExportScope.allUnits:
          // No scope filter for payments — rely on period filter alone.
          break;
      }

      if (paymentFilter != null) {
        parts.add('($paymentFilter)');
      }

      final filter = parts.isEmpty
          ? null
          : _pb.filter(parts.join(' && '), params);

      // If there's no filter at all, don't fetch payments.
      if (filter == null || filter.isEmpty) return [];

      return await _paginatedGet(
        collection: Collections.payments,
        filter: filter,
        sort: 'date',
      );
    } catch (e) {
      throw asAppException(e);
    }
  }

  /// Builds the payment period filter string. Returns null for [allTime].
  String? _buildPaymentFilter(
    ExportPeriod period,
    String? fy,
    int? year,
    int? month,
  ) {
    if (period == ExportPeriod.fiscalYear) {
      if (fy == null || fy.isEmpty) {
        throw const AppException('Choose a fiscal year.');
      }
      return _pb.filter('fy = {:fy}', {'fy': fy});
    } else if (period == ExportPeriod.month) {
      if (year == null || month == null) {
        throw const AppException('Choose a month.');
      }
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 1);
      return _pb.filter(
        'date >= {:start} && date < {:end}',
        {'start': pbFilterDate(start), 'end': pbFilterDate(end)},
      );
    }
    return null; // allTime
  }

  /// Paginated fetch — collects ALL pages for a query into a single list.
  /// Uses [perPage] records per request to keep each HTTP response small.
  ///
  /// Termination uses [ResultList.totalPages] from the server response,
  /// NOT a comparison against our requested [_perPage]. PocketBase may cap
  /// the actual per-page count below what we requested (configurable
  /// `maxPerPage` in Admin settings), so comparing `items.length < _perPage`
  /// would terminate the loop one page early and silently truncate the
  /// export — "all units" reports would contain only 200-300 rows.
  Future<List<RecordModel>> _paginatedGet({
    required String collection,
    String? filter,
    String? expand,
    String? sort,
  }) async {
    final all = <RecordModel>[];
    int page = 1;
    while (true) {
      final result = await _pb.collection(collection).getList(
            page: page,
            perPage: _perPage,
            filter: filter,
            expand: expand,
            sort: sort,
          );
      all.addAll(result.items);
      if (result.items.isEmpty || page >= result.totalPages) break;
      page++;
    }
    return all;
  }

  static bool _isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
}
