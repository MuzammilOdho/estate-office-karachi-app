import 'package:pocketbase/pocketbase.dart';

class ColonyModel {
  final String id;
  final String name;
  final int sortOrder;

  const ColonyModel({
    required this.id,
    required this.name,
    this.sortOrder = 0,
  });

  factory ColonyModel.fromRecord(RecordModel record) {
    return ColonyModel(
      id: record.id,
      name: record.get<String>('name', ''),
      sortOrder: record.get<int>('sort_order', 0),
    );
  }
}
