import 'package:pocketbase/pocketbase.dart';

import '../config/constants.dart';
import '../models/allottee_model.dart';
import '../services/pocketbase_service.dart';
import '../utils/app_exception.dart';

class AllotteesRepository {
  PocketBase get _pb => PocketBaseService.instance.client;

  Future<List<AllotteeModel>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final records = await _pb.collection(Collections.allottees).getFullList(
        filter: _pb.filter(
          'name ~ {:q} || cnic ~ {:q}',
          {'q': q},
        ),
        sort: 'name',
      );
      return records.map(AllotteeModel.fromRecord).toList();
    } catch (e) {
      throw asAppException(e);
    }
  }

  Future<AllotteeModel> getAllottee(String id) async {
    try {
      final record = await _pb.collection(Collections.allottees).getOne(id);
      return AllotteeModel.fromRecord(record);
    } catch (e) {
      throw asAppException(e);
    }
  }

  /// CNIC and DOB are optional here — a lot of historical records won't
  /// have them yet and staff fill them in later via "Modify allottee
  /// info" once they have paperwork to verify against.
  Future<AllotteeModel> createAllottee({
    required String name,
    String cnic = '',
    String designation = '',
    String department = '',
    String bs = '',
    DateTime? dob,
  }) async {
    try {
      final record = await _pb.collection(Collections.allottees).create(body: {
        'name': name.trim(),
        'cnic': cnic.trim(),
        'designation': designation.trim(),
        'department': department.trim(),
        'bs': bs.trim(),
        'dob': dob?.toIso8601String() ?? '',
        if (_pb.authStore.record?.id != null) 'created_by': _pb.authStore.record!.id,
      });
      return AllotteeModel.fromRecord(record);
    } catch (e) {
      throw asAppException(e);
    }
  }

  /// Applies an already-vetted set of field changes to an allottee
  /// record. Only called from AllotteeModificationsRepository, after the
  /// audit trail for the change has been written — never called directly
  /// from UI code, so every update to an allottee is always accompanied
  /// by a documented reason.
  Future<void> updateAllottee(String allotteeId, Map<String, dynamic> body) async {
    try {
      await _pb.collection(Collections.allottees).update(allotteeId, body: body);
    } catch (e) {
      throw asAppException(e);
    }
  }
}