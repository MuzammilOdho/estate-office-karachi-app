import 'package:pocketbase/pocketbase.dart';

import '../config/constants.dart';
import '../models/allotment_model.dart';
import '../services/pocketbase_service.dart';
import '../utils/app_exception.dart';
import 'audit_log_repository.dart';

class AllotmentsRepository {
  final AuditLogRepository _auditLogRepository = AuditLogRepository();

  PocketBase get _pb => PocketBaseService.instance.client;

  Future<AllotmentModel?> getActiveAllotmentForUnit(String unitId) async {
    try {
      final records = await _pb.collection(Collections.allotments).getFullList(
        filter: _pb.filter('unit = {:unitId}', {'unitId': unitId}),
        sort: '-date_of_allotment',
      );
      for (final r in records) {
        final allotment = AllotmentModel.fromRecord(r);
        if (allotment.isActive) return allotment;
      }
      return null;
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
  /// recent first. Backs the Allotment History screen, since once a unit
  /// is vacated its previous allottee otherwise becomes completely
  /// inaccessible (getActiveAllotmentForUnit only ever returns the
  /// current one, by design).
  Future<List<AllotmentModel>> getAllAllotmentsForUnit(String unitId) async {
    try {
      final records = await _pb.collection(Collections.allotments).getFullList(
        filter: _pb.filter('unit = {:unitId}', {'unitId': unitId}),
        sort: '-date_of_allotment',
      );
      return records.map(AllotmentModel.fromRecord).toList();
    } catch (e) {
      throw asAppException(e);
    }
  }
}