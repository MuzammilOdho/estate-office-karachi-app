import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../config/constants.dart';
import '../models/allotment_model.dart';
import '../models/unit_list_item.dart';
import '../models/unit_model.dart';
import '../services/pocketbase_service.dart';
import '../utils/app_exception.dart';
import '../utils/natural_sort.dart';
import '../utils/paged_result.dart';

class UnitsRepository {
  PocketBase get _pb => PocketBaseService.instance.client;

  /// Ceiling on global-search result rows per query. Same order as the
  /// audit log's own page size — generous enough that a real search never
  /// hits it, small enough that no single search transfers a meaningful
  /// slice of a 10k-unit estate.
  static const _searchPageSize = 200;

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
      // Scoped to only this colony+type's units — never the estate-wide
      // active-allotment table (which is what the old shared helper did).
      final joined = await _joinUnitsWithActiveAllotmentsFor(unitRecords);
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
  ///
  /// Two bounded queries, not a full-table scan: (1) units whose own
  /// text fields match the query; (2) active allotments whose allottee
  /// or unit fields match, with allottee + unit expanded. The union is
  /// small (typically tens of rows), so the existing client-side ranking
  /// runs over just the matches, not the whole estate.
  Future<List<UnitListItem>> searchAllUnits(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    try {
      // (1) Units matching on their own fields. `~` is PocketBase's
      // case-insensitive contains, so we pass the raw (not lowercased)
      // query here — _matchScore still lowercases for ranking below.
      final unitsPage = await _pb.collection(Collections.units).getList(
        page: 1,
        perPage: _searchPageSize,
        filter: _pb.filter(
          'house_no ~ {:q} || block ~ {:q} || flat_no ~ {:q} || '
              'colony ~ {:q} || type ~ {:q}',
          {'q': query.trim()},
        ),
      );

      // (2) Active allotments matching on allottee fields OR on the
      // related unit's fields (a search by house no should also find an
      // allotted unit via its allotment). unit.* / allottee.* are
      // PocketBase relation-chain filters, already used by ExportRepository.
      //
      // Single query, no fallback: the old try/fallback-on-failure pattern
      // doubled the worst-case wall-clock time when the server was merely
      // slow or unreachable (two full timeouts back to back).
      final allotmentsPage =
          await _pb.collection(Collections.allotments).getList(
        page: 1,
        perPage: _searchPageSize,
        filter: _pb.filter(
          'date_of_vacancy = {:empty} && ('
              'unit.house_no ~ {:q} || unit.block ~ {:q} || '
              'unit.flat_no ~ {:q} || unit.colony ~ {:q} || unit.type ~ {:q} || '
              'allottee.name ~ {:q} || allottee.cnic ~ {:q} || '
              'allottee.designation ~ {:q} || allottee.department ~ {:q} || '
              'allottee.personal_no ~ {:q} || allottee.phone ~ {:q}'
              ')',
          {'empty': '', 'q': query.trim()},
        ),
        expand: 'allottee, unit',
      );

      // Build the union keyed by unit id so a unit matched by both
      // queries isn't listed twice. Allotment-sourced rows carry the
      // richer allottee info; unit-sourced rows only fill it in if the
      // unit has no active allotment match above.
      final byUnit = <String, UnitListItem>{};
      for (final r in allotmentsPage.items) {
        final allotment = AllotmentModel.fromRecord(r);
        final allotteeRecord =
            r.get<RecordModel?>('expand.allottee', null);
        final unitRecord = r.get<RecordModel?>('expand.unit', null);
        if (unitRecord == null) continue; // orphaned allotment — skip
        byUnit[unitRecord.id] = UnitListItem(
          unit: UnitModel.fromRecord(unitRecord),
          activeAllotment: allotment,
          allotteeName: allotteeRecord?.get<String>('name', ''),
          allotteeCnic: allotteeRecord?.get<String>('cnic', ''),
          allotteeDesignation: allotteeRecord?.get<String>('designation', ''),
          allotteeDepartment: allotteeRecord?.get<String>('department', ''),
          allotteePersonalNo: allotteeRecord?.get<String>('personal_no', ''),
          allotteePhone: allotteeRecord?.get<String>('phone', ''),
        );
      }
      for (final r in unitsPage.items) {
        final unit = UnitModel.fromRecord(r);
        byUnit.putIfAbsent(unit.id, () => UnitListItem(unit: unit));
      }

      // Rank the small union with the same scoring logic as before.
      final scored = <MapEntry<UnitListItem, int>>[];
      for (final item in byUnit.values) {
        final score = _matchScore(item, q);
        if (score != null) scored.add(MapEntry(item, score));
      }
      scored.sort((a, b) {
        final scoreCmp = a.value.compareTo(b.value); // lower score = better
        if (scoreCmp != 0) return scoreCmp;
        return _compareUnits(a.key.unit, b.key.unit);
      });
      return scored.map((e) => e.key).toList();
    } catch (e) {
      throw asAppException(e);
    }
  }

  /// Structured, server-side search backing the advanced Search screen:
  /// Type/Category, House No., Allottee Name, CNIC and Personal No. — each
  /// one optional, every provided one AND-combined. All matching happens
  /// on the server, so with ~8,000 units only the matching rows (capped
  /// at one page of [_searchPageSize]) ever cross the LAN — never the
  /// whole estate.
  ///
  /// Allottee fields only exist through a unit's active allotment, so
  /// when any allottee field is provided the query runs against the
  /// `allotments` collection with `allottee` + `unit` expanded (a vacant
  /// unit can't match an allottee filter — exactly what AND semantics
  /// require). With only unit fields it runs against `units` and is
  /// joined with active allotments afterwards, so vacant units match too.
  Future<PagedResult<UnitListItem>> searchFilteredUnits({
    String type = '',
    String houseNo = '',
    String cnic = '',
    String name = '',
    String personalNo = '',
  }) async {
    final parts = buildSearchFilterParts(
      type: type,
      houseNo: houseNo,
      cnic: cnic,
      name: name,
      personalNo: personalNo,
    );
    if (parts.isEmpty) {
      throw const AppException('Enter at least one filter to search.');
    }

    final viaAllotments = parts.requiresAllotmentJoin;
    final template = searchFilterTemplate(parts, viaAllotments: viaAllotments);
    final params = {...parts.params, if (viaAllotments) 'empty': ''};

    try {
      if (viaAllotments) {
        final page = await _pb.collection(Collections.allotments).getList(
          page: 1,
          perPage: _searchPageSize,
          filter: _pb.filter(template, params),
          expand: 'allottee, unit',
        );
        final items = <UnitListItem>[];
        for (final r in page.items) {
          final unitRecord = r.get<RecordModel?>('expand.unit', null);
          if (unitRecord == null) continue; // orphaned allotment — skip
          final allotteeRecord = r.get<RecordModel?>('expand.allottee', null);
          items.add(UnitListItem(
            unit: UnitModel.fromRecord(unitRecord),
            activeAllotment: AllotmentModel.fromRecord(r),
            allotteeName: allotteeRecord?.get<String>('name', ''),
            allotteeCnic: allotteeRecord?.get<String>('cnic', ''),
            allotteeDesignation: allotteeRecord?.get<String>('designation', ''),
            allotteeDepartment: allotteeRecord?.get<String>('department', ''),
            allotteePersonalNo: allotteeRecord?.get<String>('personal_no', ''),
            allotteePhone: allotteeRecord?.get<String>('phone', ''),
          ));
        }
        items.sort((a, b) => _compareUnits(a.unit, b.unit));
        return PagedResult(
          items: items,
          page: page.page,
          perPage: page.perPage,
          totalItems: page.totalItems,
          totalPages: page.totalPages,
        );
      }

      final page = await _pb.collection(Collections.units).getList(
        page: 1,
        perPage: _searchPageSize,
        filter: _pb.filter(template, params),
      );
      final joined = await _joinUnitsWithActiveAllotmentsFor(page.items);
      joined.sort((a, b) => _compareUnits(a.unit, b.unit));
      return PagedResult(
        items: joined,
        page: page.page,
        perPage: page.perPage,
        totalItems: page.totalItems,
        totalPages: page.totalPages,
      );
    } catch (e) {
      throw asAppException(e);
    }
  }

  /// Builds the per-field clauses for [searchFilteredUnits]. Unit-field
  /// clauses are emitted WITHOUT a relation prefix (the template builder
  /// adds `unit.` when the query runs through the allotments collection);
  /// allottee clauses always carry the `allottee.` prefix. Pure and
  /// server-free so the AND-composition logic is unit-testable.
  @visibleForTesting
  static SearchFilterParts buildSearchFilterParts({
    String type = '',
    String houseNo = '',
    String cnic = '',
    String name = '',
    String personalNo = '',
  }) {
    final t = type.trim();
    final hn = houseNo.trim();
    final c = cnic.trim();
    final n = name.trim();
    final pn = personalNo.trim();

    final unitClauses = <SearchFilterClause>[];
    final allotteeClauses = <SearchFilterClause>[];

    if (t.isNotEmpty) {
      unitClauses.add(
        SearchFilterClause(fields: const ['type'], paramName: 'type', paramValue: t),
      );
    }
    // One "House No." field, but a unit's identifying number may live in
    // house_no, block, or flat_no (standalone house vs block of flats), so
    // the criterion ORs the three identifier columns. The group as a whole
    // still ANDs with every other filter.
    if (hn.isNotEmpty) {
      unitClauses.add(
        SearchFilterClause(
          fields: const ['house_no', 'block', 'flat_no'],
          paramName: 'houseNo',
          paramValue: hn,
        ),
      );
    }
    if (n.isNotEmpty) {
      allotteeClauses.add(
        SearchFilterClause(fields: const ['name'], paramName: 'name', paramValue: n),
      );
    }
    if (c.isNotEmpty) {
      allotteeClauses.add(
        SearchFilterClause(fields: const ['cnic'], paramName: 'cnic', paramValue: c),
      );
    }
    if (pn.isNotEmpty) {
      allotteeClauses.add(
        SearchFilterClause(
          fields: const ['personal_no'],
          paramName: 'personalNo',
          paramValue: pn,
        ),
      );
    }

    return SearchFilterParts(
      unitClauses: unitClauses,
      allotteeClauses: allotteeClauses,
    );
  }

  /// Joins the clauses into the final filter template with AND logic.
  /// When [viaAllotments] is true the query targets the allotments
  /// collection, so unit-field clauses get the `unit.` relation prefix and
  /// the active-allotment condition (`date_of_vacancy = ''`) is prepended.
  @visibleForTesting
  static String searchFilterTemplate(
    SearchFilterParts parts, {
    required bool viaAllotments,
  }) {
    final unitPrefix = viaAllotments ? 'unit.' : '';
    final clauses = [
      if (viaAllotments) 'date_of_vacancy = {:empty}',
      for (final c in parts.unitClauses) _clauseExpr(c, unitPrefix),
      for (final c in parts.allotteeClauses) _clauseExpr(c, 'allottee.'),
    ];
    return clauses.join(' && ');
  }

  static String _clauseExpr(SearchFilterClause clause, String prefix) {
    final comparisons =
        clause.fields.map((f) => '$prefix$f ~ {:${clause.paramName}}');
    // Parenthesize OR groups so they AND correctly with the other clauses.
    return comparisons.length == 1
        ? comparisons.first
        : '(${comparisons.join(' || ')})';
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
      (item.allotteePersonalNo ?? '').toLowerCase(),
      (item.allotteePhone ?? '').toLowerCase(),
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
  /// one active allotment at most — enforced on the server, see the
  /// backend handover notes) and that allotment's allottee. Scoped to only
  /// the given units so this never transfers the estate-wide active-
  /// allotment table.
  ///
  /// PocketBase's `?=` operator checks if *any element of the left-hand
  /// array field* equals a single scalar on the right — it is NOT an
  /// "IN list" operator and cannot accept a Dart List as a placeholder
  /// value, so we build `unit = 'id1' || unit = 'id2' || …` manually.
  /// IDs are chunked into batches of [_idBatchSize] because the filter is
  /// sent as a GET query parameter — a few hundred IDs would produce a URL
  /// too long for the server (HTTP 414 / parser failure), which surfaced
  /// as "Something went wrong" on colonies with many units.
  static const _idBatchSize = 40;

  Future<List<UnitListItem>> _joinUnitsWithActiveAllotmentsFor(
      List<RecordModel> unitRecords,
      ) async {
    final unitIds = [for (final r in unitRecords) r.id];
    if (unitIds.isEmpty) {
      return unitRecords
          .map((r) => UnitListItem(unit: UnitModel.fromRecord(r)))
          .toList();
    }

    final allotmentByUnit = <String, RecordModel>{};

    // Chunk IDs to keep each request URL short. For each batch, build an
    // OR-filter and paginate until that batch's matches are exhausted.
    for (var i = 0; i < unitIds.length; i += _idBatchSize) {
      final end = (i + _idBatchSize < unitIds.length)
          ? i + _idBatchSize
          : unitIds.length;
      final batch = unitIds.sublist(i, end);

      final orParts = batch.map((id) => "unit = '$id'").join(' || ');
      final filter = _pb.filter(
        'date_of_vacancy = {:empty} && ($orParts)',
        {'empty': ''},
      );

      int page = 1;
      const perPage = 500;
      while (true) {
        final result = await _pb.collection(Collections.allotments).getList(
              page: page,
              perPage: perPage,
              filter: filter,
              expand: 'allottee',
            );
        for (final r in result.items) {
          allotmentByUnit[r.get<String>('unit', '')] = r;
        }
        if (page * perPage >= result.totalItems) break;
        page++;
      }
    }

    return unitRecords.map((r) {
      final unit = UnitModel.fromRecord(r);
      final allotmentRecord = allotmentByUnit[unit.id];
      if (allotmentRecord == null) {
        return UnitListItem(unit: unit);
      }

      final allotment = AllotmentModel.fromRecord(allotmentRecord);
      final allotteeRecord = allotmentRecord.get<RecordModel?>('expand.allottee');

      return UnitListItem(
        unit: unit,
        activeAllotment: allotment,
        allotteeName: allotteeRecord?.get<String>('name', ''),
        allotteeCnic: allotteeRecord?.get<String>('cnic', ''),
        allotteeDesignation: allotteeRecord?.get<String>('designation', ''),
        allotteeDepartment: allotteeRecord?.get<String>('department', ''),
        allotteePersonalNo: allotteeRecord?.get<String>('personal_no', ''),
        allotteePhone: allotteeRecord?.get<String>('phone', ''),
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

/// One field criterion for [UnitsRepository.searchFilteredUnits]: the
/// column(s) to match (OR-combined when several) and the bound parameter.
class SearchFilterClause {
  final List<String> fields;
  final String paramName;
  final String paramValue;

  const SearchFilterClause({
    required this.fields,
    required this.paramName,
    required this.paramValue,
  });
}

/// The clauses + bound params produced by
/// [UnitsRepository.buildSearchFilterParts].
class SearchFilterParts {
  final List<SearchFilterClause> unitClauses;
  final List<SearchFilterClause> allotteeClauses;

  const SearchFilterParts({
    required this.unitClauses,
    required this.allotteeClauses,
  });

  /// True when at least one allottee-field filter is present — the query
  /// must then run through the allotments collection (relation fields).
  bool get requiresAllotmentJoin => allotteeClauses.isNotEmpty;

  bool get isEmpty => unitClauses.isEmpty && allotteeClauses.isEmpty;

  Map<String, dynamic> get params => {
        for (final c in [...unitClauses, ...allotteeClauses])
          c.paramName: c.paramValue,
      };
}