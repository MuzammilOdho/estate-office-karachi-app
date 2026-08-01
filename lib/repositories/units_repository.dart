import 'package:pocketbase/pocketbase.dart';

import '../config/constants.dart';
import '../models/allotment_model.dart';
import '../models/unit_list_item.dart';
import '../models/unit_model.dart';
import '../services/pocketbase_service.dart';
import '../utils/app_exception.dart';
import '../utils/natural_sort.dart';

class UnitsRepository {
  PocketBase get _pb => PocketBaseService.instance.client;

  /// Distinct colonies, for the home screen's browse list and the Add Unit
  /// form's colony dropdown. Data-driven (not hardcoded) so a new colony
  /// needs no app update — just add a unit with that colony name.
  Future<List<String>> getColonies() async {
    try {
      final records = await _pb.collection(Collections.units).getFullList(
        sort: 'colony',
        fields: 'colony',
      );
      final colonies = <String>{};
      for (final r in records) {
        final c = r.get<String>('colony', '');
        if (c.isNotEmpty) colonies.add(c);
      }
      return colonies.toList()..sort();
    } catch (e) {
      throw asAppException(e);
    }
  }

  /// Distinct types that exist within one colony.
  Future<List<String>> getTypesForColony(String colony) async {
    try {
      final records = await _pb.collection(Collections.units).getFullList(
        filter: _pb.filter('colony = {:colony}', {'colony': colony}),
        fields: 'type',
      );
      final types = <String>{};
      for (final r in records) {
        final t = r.get<String>('type', '');
        if (t.isNotEmpty) types.add(t);
      }
      return types.toList()..sort();
    } catch (e) {
      throw asAppException(e);
    }
  }

  /// Units within one colony + type, joined with each unit's active
  /// allotment (if any) and that allottee's info for display, sorted the
  /// way a person would order house/flat numbers (natural sort — see
  /// naturalCompare), not the plain string sort PocketBase's own `sort`
  /// param would give a text column ("10" before "2").
  Future<List<UnitListItem>> getUnitsForColonyAndType({
    required String colony,
    required String type,
  }) async {
    try {
      final unitRecords = await _pb.collection(Collections.units).getFullList(
        filter: _pb.filter(
          'colony = {:colony} && type = {:type}',
          {'colony': colony, 'type': type},
        ),
      );
      final joined = await _joinWithActiveAllotments(unitRecords);
      joined.sort((a, b) => _compareUnits(a.unit, b.unit));
      return joined;
    } catch (e) {
      throw asAppException(e);
    }
  }

  /// Every unit, joined the same way — backs the home screen's global
  /// search by house/block/flat no, colony, type, allottee name/CNIC/
  /// designation/department, so staff can find a unit without drilling
  /// through colony → type first. Results are ranked so exact and
  /// starts-with matches surface before loose contains-matches.
  Future<List<UnitListItem>> searchAllUnits(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    try {
      final unitRecords = await _pb.collection(Collections.units).getFullList();
      final joined = await _joinWithActiveAllotments(unitRecords);

      final scored = <MapEntry<UnitListItem, int>>[];
      for (final item in joined) {
        final score = _matchScore(item, q);
        if (score != null) scored.add(MapEntry(item, score));
      }
      scored.sort((a, b) {
        final scoreCmp = a.value.compareTo(b.value); // lower score = better match
        if (scoreCmp != 0) return scoreCmp;
        return _compareUnits(a.key.unit, b.key.unit);
      });
      return scored.map((e) => e.key).toList();
    } catch (e) {
      throw asAppException(e);
    }
  }

  /// Lower is a better match: 0 = exact match on an identifying field,
  /// 1 = a field starts with the query, 2 = a field just contains it
  /// somewhere. Returns null (no match) if nothing matches at all.
  int? _matchScore(UnitListItem item, String q) {
    final fields = [
      item.unit.houseNo.toLowerCase(),
      item.unit.block.toLowerCase(),
      item.unit.flatNo.toLowerCase(),
      item.unit.colony.toLowerCase(),
      item.unit.type.toLowerCase(),
      (item.allotteeName ?? '').toLowerCase(),
      (item.allotteeCnic ?? '').toLowerCase(),
      (item.allotteeDesignation ?? '').toLowerCase(),
      (item.allotteeDepartment ?? '').toLowerCase(),
    ];

    var best = 3; // 3 = "no match" sentinel, filtered out below
    for (final field in fields) {
      if (field.isEmpty) continue;
      if (field == q) {
        best = 0;
        break; // can't do better than an exact match
      }
      if (field.startsWith(q) && best > 1) {
        best = 1;
      } else if (field.contains(q) && best > 2) {
        best = 2;
      }
    }
    return best == 3 ? null : best;
  }

  int _compareUnits(UnitModel a, UnitModel b) {
    final colonyCmp = naturalCompare(a.colony, b.colony);
    if (colonyCmp != 0) return colonyCmp;
    final blockCmp = naturalCompare(a.block, b.block);
    if (blockCmp != 0) return blockCmp;
    final flatCmp = naturalCompare(a.flatNo, b.flatNo);
    if (flatCmp != 0) return flatCmp;
    return naturalCompare(a.houseNo, b.houseNo);
  }

  /// Joins a list of unit records with their active allotment (a unit has
  /// one active allotment at most — enforced in AllotmentsRepository) and
  /// that allotment's allottee, in 1 extra query total instead of one
  /// query per unit.
  Future<List<UnitListItem>> _joinWithActiveAllotments(
      List<RecordModel> unitRecords,
      ) async {
    final activeAllotmentRecords =
    await _pb.collection(Collections.allotments).getFullList(
      filter: _pb.filter(
        'date_of_vacancy = {:empty}',
        {'empty': ''},
      ),
      expand: 'allottee',
    );

    final allotmentByUnit = <String, RecordModel>{};
    for (final r in activeAllotmentRecords) {
      allotmentByUnit[r.get<String>('unit', '')] = r;
    }

    return unitRecords.map((r) {
      final unit = UnitModel.fromRecord(r);
      final allotmentRecord = allotmentByUnit[unit.id];
      if (allotmentRecord == null) {
        return UnitListItem(unit: unit);
      }

      final allotment = AllotmentModel.fromRecord(allotmentRecord);
      final RecordModel? allotteeRecord =
      allotmentRecord.get<RecordModel>('expand.allottee', null);

      return UnitListItem(
        unit: unit,
        activeAllotment: allotment,
        allotteeName: allotteeRecord?.get<String>('name', ''),
        allotteeCnic: allotteeRecord?.get<String>('cnic', ''),
        allotteeDesignation: allotteeRecord?.get<String>('designation', ''),
        allotteeDepartment: allotteeRecord?.get<String>('department', ''),
      );
    }).toList();
  }

  Future<UnitModel> getUnit(String unitId) async {
    try {
      final record = await _pb.collection(Collections.units).getOne(unitId);
      return UnitModel.fromRecord(record);
    } catch (e) {
      throw asAppException(e);
    }
  }

  Future<UnitModel> createUnit({
    String houseNo = '',
    String block = '',
    String flatNo = '',
    required String colony,
    required String type,
  }) async {
    try {
      final record = await _pb.collection(Collections.units).create(body: {
        'house_no': houseNo.trim(),
        'block': block.trim(),
        'flat_no': flatNo.trim(),
        'colony': colony.trim(),
        'type': type.trim(),
        if (_pb.authStore.record?.id != null) 'created_by': _pb.authStore.record!.id,
      });
      return UnitModel.fromRecord(record);
    } catch (e) {
      throw asAppException(e);
    }
  }
}