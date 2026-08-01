// import 'package:flutter/foundation.dart';
//
// import '../models/unit_list_item.dart';
// import '../repositories/units_repository.dart';
// import '../utils/app_exception.dart';
//
// enum LoadState { loading, loaded, error }
//
// class UnitsListProvider extends ChangeNotifier {
//   final UnitsRepository _repository = UnitsRepository();
//
//   LoadState state = LoadState.loading;
//   String? errorMessage;
//   String searchQuery = '';
//
//   List<UnitListItem> _allItems = [];
//
//   Future<void> load() async {
//     state = LoadState.loading;
//     errorMessage = null;
//     notifyListeners();
//
//     try {
//       _allItems = await _repository.getUnitsWithStatus();
//       state = LoadState.loaded;
//     } catch (e) {
//       errorMessage = (e is AppException) ? e.message : 'Something went wrong.';
//       state = LoadState.error;
//     }
//     notifyListeners();
//   }
//
//   Future<void> refresh() => load();
//
//   void setSearchQuery(String query) {
//     searchQuery = query;
//     notifyListeners();
//   }
//
//   List<UnitListItem> get _visibleItems {
//     final q = searchQuery.trim().toLowerCase();
//     if (q.isEmpty) return _allItems;
//     return _allItems.where((item) {
//       final unitNo = item.unit.unitNo.toLowerCase();
//       final allottee = item.activeAllotment?.allotteeName.toLowerCase() ?? '';
//       return unitNo.contains(q) || allottee.contains(q);
//     }).toList();
//   }
//
//   /// Units grouped by area, area names sorted alphabetically, units within
//   /// an area sorted by block then unit number (spec §6.3 — "grouped by
//   /// Area").
//   List<MapEntry<String, List<UnitListItem>>> get groupedByArea {
//     final map = <String, List<UnitListItem>>{};
//     for (final item in _visibleItems) {
//       map.putIfAbsent(item.unit.area, () => []).add(item);
//     }
//     final entries = map.entries.toList()
//       ..sort((a, b) => a.key.compareTo(b.key));
//     return entries;
//   }
//
//   bool get isEmpty => _allItems.isEmpty;
//   bool get hasNoSearchResults => _allItems.isNotEmpty && _visibleItems.isEmpty;
// }