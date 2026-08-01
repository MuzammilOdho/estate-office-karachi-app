import 'package:pocketbase/pocketbase.dart';

class CategoryModel {
  final String id;
  final String name;
  final String colonyId;
  final int sortOrder;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.colonyId,
    this.sortOrder = 0,
  });

  factory CategoryModel.fromRecord(RecordModel record) {
    return CategoryModel(
      id: record.id,
      name: record.get<String>('name', ''),
      colonyId: record.get<String>('colony', ''),
      sortOrder: record.get<int>('sort_order', 0),
    );
  }
}
