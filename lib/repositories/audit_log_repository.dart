import 'package:pocketbase/pocketbase.dart';

import '../config/constants.dart';
import '../models/audit_log_entry.dart';
import '../services/pocketbase_service.dart';
import '../utils/app_exception.dart';

class AuditLogRepository {
  PocketBase get _pb => PocketBaseService.instance.client;

  /// Writes one activity-feed entry. Deliberately swallows its own
  /// errors — a failed audit-log write should never block or fail the
  /// real action (adding a payment, allotting a unit, etc.) that it's
  /// just a record of.
  Future<void> logBestEffort({
    required String action,
    required String entityType,
    required String entityId,
    required String summary,
  }) async {
    try {
      final currentUserId = _pb.authStore.record?.id;
      await _pb.collection(Collections.auditLog).create(body: {
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'summary': summary,
        if (currentUserId != null) 'performed_by': currentUserId,
      });
    } catch (_) {
      // Best-effort only — see doc comment above.
    }
  }

  /// The admin activity feed, most recent first.
  Future<List<AuditLogEntry>> getRecent({int limit = 200}) async {
    try {
      final records = await _pb.collection(Collections.auditLog).getList(
        page: 1,
        perPage: limit,
        sort: '-created',
        expand: 'performed_by',
      );
      return records.items.map(AuditLogEntry.fromRecord).toList();
    } catch (e) {
      throw asAppException(e);
    }
  }
}