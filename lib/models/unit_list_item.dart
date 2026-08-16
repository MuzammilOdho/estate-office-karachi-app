import 'allotment_model.dart';
import 'unit_model.dart';

/// One row on a units list (browse or search): a unit plus its active
/// allotment and allottee info, if any. Status is never stored — it's
/// just "activeAllotment != null" computed at fetch time.
/// Designation/department/phone/personal_no aren't shown on the card today
/// but are used by UnitsRepository's search matching.
class UnitListItem {
  final UnitModel unit;
  final AllotmentModel? activeAllotment;
  final String? allotteeName;
  final String? allotteeCnic;
  final String? allotteeDesignation;
  final String? allotteeDepartment;
  final String? allotteePersonalNo;
  final String? allotteePhone;

  const UnitListItem({
    required this.unit,
    this.activeAllotment,
    this.allotteeName,
    this.allotteeCnic,
    this.allotteeDesignation,
    this.allotteeDepartment,
    this.allotteePersonalNo,
    this.allotteePhone,
  });

  bool get isAllotted => activeAllotment != null;
}