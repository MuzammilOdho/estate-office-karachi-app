import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../config/constants.dart';
import '../models/allottee_modification_model.dart';
import 'allottees_repository.dart';
import 'audit_log_repository.dart';
import '../services/pocketbase_service.dart';
import '../utils/app_exception.dart';

/// One editable field on an allottee, used to build the diff shown to
/// admins later. [label] is what's displayed; [oldValue]/[newValue] are
/// already-formatted display strings (not raw typed values) since the
/// diff is for a human to read, not for the app to act on.
class AllotteeFieldEdit {
  final String label;
  final String oldValue;
  final String newValue;

  const AllotteeFieldEdit({
    required this.label,
    required this.oldValue,
    required this.newValue,
  });

  bool get isChanged => oldValue.trim() != newValue.trim();
}

class AllotteeModificationsRepository {
  final AllotteesRepository _allotteesRepository = AllotteesRepository();
  final AuditLogRepository _auditLogRepository = AuditLogRepository();

  PocketBase get _pb => PocketBaseService.instance.client;

  /// Records the change (with its supporting documents) and then applies
  /// it to the live allottee record — in that order, so a documented,
  /// attributed record of the intended change exists even in the rare
  /// case the second write fails (same reasoning as the allot/vacate
  /// one-logical-action handling elsewhere in this app).
  Future<void> submitModification({
    required String allotteeId,
    required List<AllotteeFieldEdit> edits,
    required Map<String, dynamic> updateBody,
    required String remarks,
    required List<List<int>> documentBytesList,
    required List<String> documentFilenames,
  }) async {
    final changed = edits.where((e) => e.isChanged).toList();
    if (changed.isEmpty) {
      throw const AppException('No changes were made.');
    }
    if (documentBytesList.isEmpty) {
      throw const AppException(
        'Attach at least one supporting document before saving.',
      );
    }

    final currentUserId = _pb.authStore.record?.id;
    if (currentUserId == null) {
      throw const AppException('Your session has expired. Please log in again.');
    }

    final changesJson = <String, dynamic>{
      for (final e in changed) e.label: {'old': e.oldValue, 'new': e.newValue},
    };

    try {
      await _pb.collection(Collections.allotteeModifications).create(
        body: {
          'allottee': allotteeId,
          'changes': changesJson,
          'remarks': remarks.trim(),
          'changed_by': currentUserId,
        },
        files: [
          for (var i = 0; i < documentBytesList.length; i++)
            http.MultipartFile.fromBytes(
              'documents',
              documentBytesList[i],
              filename: documentFilenames[i],
            ),
        ],
      );
    } catch (e) {
      throw asAppException(e);
    }

    // Apply the change to the live record — the raw values the form
    // actually holds, not a reconstruction of the display diff above.
    await _allotteesRepository.updateAllottee(allotteeId, updateBody);

    await _auditLogRepository.logBestEffort(
      action: 'allottee_modified',
      entityType: Collections.allottees,
      entityId: allotteeId,
      summary: 'Allottee info updated (${changed.map((e) => e.label).join(', ')})',
    );
  }

  /// Modification history for one allottee, most recent first, with
  /// document URLs resolved using a single shared protected-file token
  /// (fetched once here rather than per document).
  Future<List<AllotteeModificationModel>> getHistoryForAllottee(
      String allotteeId,
      ) async {
    try {
      final records = await _pb.collection(Collections.allotteeModifications).getFullList(
        filter: _pb.filter('allottee = {:id}', {'id': allotteeId}),
        sort: '-created',
        expand: 'changed_by',
      );
      final fileToken = await _pb.files.getToken();
      return records
          .map((r) => AllotteeModificationModel.fromRecord(r, _pb, fileToken))
          .toList();
    } catch (e) {
      throw asAppException(e);
    }
  }
}