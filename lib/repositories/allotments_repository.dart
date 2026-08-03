import 'package:pocketbase/pocketbase.dart';

import '../config/constants.dart';
import '../models/allotment_model.dart';
import '../models/allottee_model.dart';
import '../services/pocketbase_service.dart';
import '../utils/app_exception.dart';
import 'audit_log_repository.dart';

/// An allotment paired with its (possibly missing) allottee, resolved
/// in a single query via `expand`. Used by the allotment history screen.
class AllotmentWithAllottee {
  final AllotmentModel allotment;
  final AllotteeModel? allottee;
  const AllotmentWithAllottee(this.allotment, this.allottee);
}

class AllotmentsRepository {
  final AuditLogRepository _auditLogRepository = AuditLogRepository();

  PocketBase get _pb => PocketBaseService.instance.client;

  /// The active allotment for a unit, if any. An allotment is active
  /// exactly when `date_of_vacancy` is empty — so we filter on that
  /// server-side and ask for just the one matching row, instead of
  /// fetching the unit's entire allotment history and picking through it
  /// in Dart.
  Future<AllotmentModel?> getActiveAllotmentForUnit(String unitId) async {
    try {
      final result = await _pb.collection(Collections.allotments).getList(
        page: 1,
        perPage: 1,
        filter: _pb.filter(
          'unit = {:unitId} && date_of_vacancy = {:empty}',
          {'unitId': unitId, 'empty': ''},
        ),
        sort: '-date_of_allotment',
      );
      if (result.items.isEmpty) return null;
      return AllotmentModel.fromRecord(result.items.first);
    } catch (e) {
      throw asAppException(e);
    }
  }

  /// [unitLabel]/[allotteeName] are only for the audit log's human-
  /// readable summary — the caller already has them on hand from the UI.
  Future<AllotmentModel> allotUnit({
    required String unitId,
    required String allotteeId,
    required DateTime dateOfAllotment,
    required DateTime dateOfOccupation,
    String unitLabel = '',
    String allotteeName = '',
  }) async {
    final existing = await getActiveAllotmentForUnit(unitId);
    if (existing != null) {
      throw const AppException(
        'This unit already has an active allotment. Refresh and try again.',
      );
    }

    RecordModel record;
    try {
      record = await _pb.collection(Collections.allotments).create(body: {
        'unit': unitId,
        'allottee': allotteeId,
        'date_of_allotment': dateOfAllotment.toIso8601String(),
        'date_of_occupation': dateOfOccupation.toIso8601String(),
        if (_pb.authStore.record?.id != null) 'created_by': _pb.authStore.record!.id,
      });
    } catch (e) {
      throw asAppException(e);
    }

    final allotment = AllotmentModel.fromRecord(record);

    await _auditLogRepository.logBestEffort(
      action: 'unit_allotted',
      entityType: Collections.allotments,
      entityId: allotment.id,
      summary:
      '${unitLabel.isNotEmpty ? unitLabel : "Unit $unitId"} allotted to '
          '${allotteeName.isNotEmpty ? allotteeName : allotteeId}',
    );

    return allotment;
  }

  Future<void> vacateAllotment({
    required String allotmentId,
    required DateTime dateOfVacancy,
    String unitLabel = '',
    String allotteeName = '',
  }) async {
    try {
      await _pb.collection(Collections.allotments).update(allotmentId, body: {
        'date_of_vacancy': dateOfVacancy.toIso8601String(),
        if (_pb.authStore.record?.id != null) 'vacated_by': _pb.authStore.record!.id,
      });
    } catch (e) {
      throw asAppException(e);
    }

    await _auditLogRepository.logBestEffort(
      action: 'unit_vacated',
      entityType: Collections.allotments,
      entityId: allotmentId,
      summary:
      '${unitLabel.isNotEmpty ? unitLabel : "Unit"} vacated'
          '${allotteeName.isNotEmpty ? " ($allotteeName)" : ""}',
    );
  }

  /// Every allotment this unit has ever had — active and vacated — most
  /// recent first, each with its allottee expanded. Backs the Allotment
  /// History screen, since once a unit is vacated its previous allottee
  /// otherwise becomes completely inaccessible (getActiveAllotmentForUnit
  /// only ever returns the current one, by design). `expand: 'allottee'`
  /// resolves the allottee in the same query, avoiding an N+1 of
  /// per-allotment getAllottee calls.
  Future<List<AllotmentWithAllottee>> getAllAllotmentsForUnit(
      String unitId) async {
    try {
      final records = await _pb.collection(Collections.allotments).getFullList(
        filter: _pb.filter('unit = {:unitId}', {'unitId': unitId}),
        sort: '-date_of_allotment',
        expand: 'allottee',
      );
      return records.map((r) {
        final allotment = AllotmentModel.fromRecord(r);
        final allotteeRecord = r.get<RecordModel?>('expand.allottee', null);
        final allottee = allotteeRecord == null
            ? null
            : AllotteeModel.fromRecord(allotteeRecord);
        return AllotmentWithAllottee(allotment, allottee);
      }).toList();
    } catch (e) {
      throw asAppException(e);
    }
  }
}