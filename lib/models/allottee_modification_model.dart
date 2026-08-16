import 'package:pocketbase/pocketbase.dart';

import '../utils/user_display.dart';

/// One changed field: what it was, what it became. Values are stored as
/// display strings (not typed) since the diff itself is just for a human
/// to read in the history log.
class FieldChange {
  final String fieldLabel;
  final String oldValue;
  final String newValue;

  const FieldChange({
    required this.fieldLabel,
    required this.oldValue,
    required this.newValue,
  });
}

/// One audited edit to an allottee's info, with the supporting documents
/// staff uploaded as verification.
class AllotteeModificationModel {
  final String id;
  final String allotteeId;
  final List<FieldChange> changes;
  final List<String> documentUrls;
  final String remarks;
  final String changedByName;
  final DateTime changedAt;

  const AllotteeModificationModel({
    required this.id,
    required this.allotteeId,
    required this.changes,
    required this.documentUrls,
    required this.remarks,
    required this.changedByName,
    required this.changedAt,
  });

  /// [record] should have been fetched with `expand: 'changed_by'`.
  /// [fileToken] is a short-lived protected-file token (see
  /// AllotteeModificationsRepository) shared across a batch of records so
  /// we don't request a fresh one per document.
  factory AllotteeModificationModel.fromRecord(
      RecordModel record,
      PocketBase pb,
      String fileToken,
      ) {
    final changesRaw = record.get<Map<String, dynamic>>('changes', {});
    final changes = changesRaw.entries.map((entry) {
      final v = entry.value;
      final old = (v is Map ? v['old'] : null)?.toString() ?? '';
      final updated = (v is Map ? v['new'] : null)?.toString() ?? '';
      return FieldChange(fieldLabel: entry.key, oldValue: old, newValue: updated);
    }).toList();

    final filenames = record.get<List<String>>('documents', const []);
    final documentUrls = filenames
        .map((f) => pb.files.getURL(record, f, token: fileToken).toString())
        .toList();

    final changedByRecord =
    record.get<RecordModel>('expand.changed_by', null);

    final rawCreated = record.get<String>('created', '');

    return AllotteeModificationModel(
      id: record.id,
      allotteeId: record.get<String>('allottee', ''),
      changes: changes,
      documentUrls: documentUrls,
      remarks: record.get<String>('remarks', ''),
      changedByName: UserDisplay.nameFromRecord(changedByRecord),
      changedAt: DateTime.tryParse(rawCreated) ?? DateTime.now(),
    );
  }
}