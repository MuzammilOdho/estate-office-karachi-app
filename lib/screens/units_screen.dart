import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/unit_list_item.dart';
import '../providers/auth_provider.dart';
import '../repositories/units_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../widgets/state_views.dart';
import '../widgets/unit_card.dart';
import 'add_unit_sheet.dart';
import 'unit_detail_sheet.dart';

class UnitsScreen extends StatefulWidget {
  final String colony;
  final String type;
  const UnitsScreen({super.key, required this.colony, required this.type});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

enum _LoadState { loading, loaded, error }

class _UnitsScreenState extends State<UnitsScreen> {
  final _unitsRepository = UnitsRepository();
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  List<UnitListItem> _allItems = [];

  // Local filter state. Kept in a field (not derived per-build) so the
  // filtered list is recomputed only when the filter or the source list
  // actually changes, not on every rebuild.
  String _filter = '';
  List<UnitListItem> _visibleItems = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _state = _LoadState.loading;
      _errorMessage = null;
    });
    try {
      final items = await _unitsRepository.getUnitsForColonyAndType(
        colony: widget.colony,
        type: widget.type,
      );
      if (!mounted) return;
      setState(() {
        _allItems = items;
        _visibleItems = _applyFilter(items, _filter);
        _state = _LoadState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is AppException ? e.message : 'Something went wrong.';
        _state = _LoadState.error;
      });
    }
  }

  void _onFilterChanged(String value) {
    final newFilter = value.trim().toLowerCase();
    if (newFilter == _filter) return;
    setState(() {
      _filter = newFilter;
      _visibleItems = _applyFilter(_allItems, newFilter);
    });
  }

  /// Filters [items] by [query] against house no / block / flat no /
  /// allottee name / CNIC. Pure function so it can be called from both
  /// [_load] and [_onFilterChanged] without duplicating the predicate.
  static List<UnitListItem> _applyFilter(
      List<UnitListItem> items, String query) {
    if (query.isEmpty) return items;
    return items.where((item) {
      final houseNo = item.unit.houseNo.toLowerCase();
      final block = item.unit.block.toLowerCase();
      final flatNo = item.unit.flatNo.toLowerCase();
      final allottee = (item.allotteeName ?? '').toLowerCase();
      final cnic = (item.allotteeCnic ?? '').toLowerCase();
      final personalNo = (item.allotteePersonalNo ?? '').toLowerCase();
      final phone = (item.allotteePhone ?? '').toLowerCase();
      return houseNo.contains(query) ||
          block.contains(query) ||
          flatNo.contains(query) ||
          allottee.contains(query) ||
          cnic.contains(query) ||
          personalNo.contains(query) ||
          phone.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.colony} · ${widget.type}')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                onChanged: _onFilterChanged,
                decoration: const InputDecoration(
                  hintText: 'Search house no, allottee name, or CNIC',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: context.watch<AuthProvider>().isAdmin
          ? FloatingActionButton(
        tooltip: 'Add unit',
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) =>
              AddUnitSheet(initialColony: widget.colony, initialType: widget.type),
        ).then((_) => _load()),
        child: const Icon(Icons.add),
      )
          : null,
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.loading:
        return const LoadingView(message: 'Loading units…');
      case _LoadState.error:
        return ErrorRetryView(
          message: _errorMessage ?? 'Something went wrong.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        if (_allItems.isEmpty) {
          return const EmptyStateView(
            icon: Icons.home_work_outlined,
            title: 'No units here yet',
            subtitle: 'Tap the + button to add one.',
          );
        }
        if (_visibleItems.isEmpty) {
          return const EmptyStateView(
            icon: Icons.search_off_rounded,
            title: 'No matches',
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            itemCount: _visibleItems.length,
            itemBuilder: (context, index) {
              final item = _visibleItems[index];
              return UnitCard(
                key: ValueKey(item.unit.id),
                item: item,
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => UnitDetailSheet(unitId: item.unit.id),
                ).then((_) => _load()),
              );
            },
          ),
        );
    }
  }
}
