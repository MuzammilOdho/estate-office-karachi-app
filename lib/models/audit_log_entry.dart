import 'package:pocketbase/pocketbase.dart';

import '../utils/user_display.dart';

/// One entry in the global activity feed (units created, allotments made
/// or vacated, payments recorded, allottee info modified). This is
/// intentionally a flat, human-readable log — not a structured diff
/// (that level of detail lives in AllotteeModificationModel for the one
/// action that needs it).
class AuditLogEntry {
  final String id;
  final String action;
  final String summary;
  final String entityType;
  final String entityId;
  final String performedByName;
  final DateTime performedAt;

  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.summary,
    required this.entityType,
    required this.entityId,
    required this.performedByName,
    required this.performedAt,
  });

  /// [record] should have been fetched with `expand: 'performed_by'`.
  factory AuditLogEntry.fromRecord(RecordModel record) {
    final RecordModel? performedByRecord =
    record.get<RecordModel>('expand.performed_by', null);
    final rawCreated = record.get<String>('created', '');

    return AuditLogEntry(
      id: record.id,
      action: record.get<String>('action', ''),
      summary: record.get<String>('summary', ''),
      entityType: record.get<String>('entity_type', ''),
      entityId: record.get<String>('entity_id', ''),
      performedByName: UserDisplay.nameFromRecord(performedByRecord),
      performedAt: rawCreated.isEmpty ? DateTime.now() : DateTime.parse(rawCreated),
    );
  }
}