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
  String _filter = '';

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

  List<UnitListItem> get _visibleItems {
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return _allItems;
    return _allItems.where((item) {
      final houseNo = item.unit.houseNo.toLowerCase();
      final block = item.unit.block.toLowerCase();
      final flatNo = item.unit.flatNo.toLowerCase();
      final allottee = (item.allotteeName ?? '').toLowerCase();
      final cnic = (item.allotteeCnic ?? '').toLowerCase();
      return houseNo.contains(q) ||
          block.contains(q) ||
          flatNo.contains(q) ||
          allottee.contains(q) ||
          cnic.contains(q);
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
                onChanged: (v) => setState(() => _filter = v),
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
        final visible = _visibleItems;
        if (visible.isEmpty) {
          return const EmptyStateView(
            icon: Icons.search_off_rounded,
            title: 'No matches',
          );
        }
        return RefreshIndicator(
          color: AppColors.brass,
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final item = visible[index];
              return UnitCard(
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