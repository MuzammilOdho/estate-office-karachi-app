import 'package:pocketbase/pocketbase.dart';

/// A physical unit. house_no / block / flat_no are all optional — real
/// accommodation records only populate whichever ones apply (a standalone
/// house has a house_no and no block/flat; a block of flats has block +
/// flat_no and no house_no). "Status" (allotted/vacant) and "allottee"
/// are NOT stored here: they're always computed from whether an active
/// allotment exists (see AllotmentsRepository).
class UnitModel {
  final String id;
  final String houseNo;
  final String block;
  final String flatNo;
  final String colony;
  final String type;

  const UnitModel({
    required this.id,
    required this.houseNo,
    required this.block,
    required this.flatNo,
    required this.colony,
    required this.type,
  });

  /// A single human-readable label built from whichever of
  /// house_no/block/flat_no are actually set, e.g. "House 12",
  /// "Block C · Flat 4", or "Block C · Flat 4 / House 12" if a record has
  /// both (uncommon but not disallowed).
  String get displayLabel {
    final parts = <String>[];
    if (block.isNotEmpty && flatNo.isNotEmpty) {
      parts.add('Block $block · Flat $flatNo');
    } else if (block.isNotEmpty) {
      parts.add('Block $block');
    } else if (flatNo.isNotEmpty) {
      parts.add('Flat $flatNo');
    }
    if (houseNo.isNotEmpty) {
      parts.add('House $houseNo');
    }
    if (parts.isEmpty) return 'Unit';
    return parts.join(' / ');
  }

  factory UnitModel.fromRecord(RecordModel record) {
    return UnitModel(
      id: record.id,
      houseNo: record.get<String>('house_no', ''),
      block: record.get<String>('block', ''),
      flatNo: record.get<String>('flat_no', ''),
      colony: record.get<String>('colony', ''),
      type: record.get<String>('type', ''),
    );
  }
}