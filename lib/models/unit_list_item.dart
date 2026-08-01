import 'allotment_model.dart';
import 'unit_model.dart';

/// One row on a units list (browse or search): a unit plus its active
/// allotment and allottee info, if any. Status is never stored — it's
/// just "activeAllotment != null" computed at fetch time.
/// Designation/department aren't shown on the card today but are used
/// by UnitsRepository's search matching (e.g. searching "Police" should
/// find a unit whose allottee's department is "Police Service").
class UnitListItem {
  final UnitModel unit;
  final AllotmentModel? activeAllotment;
  final String? allotteeName;
  final String? allotteeCnic;
  final String? allotteeDesignation;
  final String? allotteeDepartment;

  const UnitListItem({
    required this.unit,
    this.activeAllotment,
    this.allotteeName,
    this.allotteeCnic,
    this.allotteeDesignation,
    this.allotteeDepartment,
  });

  bool get isAllotted => activeAllotment != null;
}