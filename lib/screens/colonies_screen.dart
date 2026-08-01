import 'dart:async';

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
import 'audit_log_screen.dart';
import 'export_screen.dart';
import 'settings_screen.dart';
import 'types_screen.dart';
import 'unit_detail_sheet.dart';

/// Home screen. Search box always on top (global — finds a unit from
/// anywhere by house no / allottee name / CNIC, no drill-down needed);
/// below it, when the search box is empty, the colony browse list.
class ColoniesScreen extends StatefulWidget {
  const ColoniesScreen({super.key});

  @override
  State<ColoniesScreen> createState() => _ColoniesScreenState();
}

enum _LoadState { loading, loaded, error }

class _ColoniesScreenState extends State<ColoniesScreen> {
  final _unitsRepository = UnitsRepository();
  final _searchController = TextEditingController();
  Timer? _debounce;

  _LoadState _coloniesState = _LoadState.loading;
  String? _errorMessage;
  List<String> _colonies = [];

  bool _isSearching = false;
  List<UnitListItem> _searchResults = [];
  bool _searchAttempted = false;

  @override
  void initState() {
    super.initState();
    _loadColonies();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadColonies() async {
    setState(() {
      _coloniesState = _LoadState.loading;
      _errorMessage = null;
    });
    try {
      final colonies = await _unitsRepository.getColonies();
      if (!mounted) return;
      setState(() {
        _colonies = colonies;
        _coloniesState = _LoadState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is AppException ? e.message : 'Something went wrong.';
        _coloniesState = _LoadState.error;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchAttempted = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _unitsRepository.searchAllUnits(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searchAttempted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is AppException ? e.message : 'Something went wrong.';
      });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _openUnit(String unitId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => UnitDetailSheet(unitId: unitId),
    ).then((_) {
      _loadColonies();
      if (_searchController.text.trim().isNotEmpty) {
        _runSearch(_searchController.text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSearchingMode = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estate Registry'),
        actions: [
          IconButton(
            tooltip: 'Export report',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExportScreen()),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              } else if (value == 'audit_log') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AuditLogScreen()),
                );
              } else if (value == 'logout') {
                context.read<AuthProvider>().logout();
              }
            },
            itemBuilder: (context) => [
              if (context.read<AuthProvider>().isAdmin)
                const PopupMenuItem(value: 'audit_log', child: Text('Audit log')),
              const PopupMenuItem(value: 'settings', child: Text('Server settings')),
              const PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {}); // toggle search-mode vs colony-list UI
                  _onSearchChanged(value);
                },
                decoration: InputDecoration(
                  hintText: 'Search house no, allottee name, or CNIC',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                      : (isSearchingMode
                      ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults = [];
                        _searchAttempted = false;
                      });
                    },
                  )
                      : null),
                ),
              ),
            ),
            Expanded(
              child: isSearchingMode ? _buildSearchResults() : _buildColoniesList(),
            ),
          ],
        ),
      ),
      floatingActionButton: (isSearchingMode || !context.watch<AuthProvider>().isAdmin)
          ? null
          : FloatingActionButton(
        tooltip: 'Add unit',
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => const AddUnitSheet(),
        ).then((_) => _loadColonies()),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      if (_isSearching) return const LoadingView();
      if (_searchAttempted) {
        return const EmptyStateView(
          icon: Icons.search_off_rounded,
          title: 'No matches',
          subtitle: 'Try a different house no, name, or CNIC.',
        );
      }
      return const SizedBox.shrink();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        return UnitCard(
          item: item,
          showColonyAndType: true,
          onTap: () => _openUnit(item.unit.id),
        );
      },
    );
  }

  Widget _buildColoniesList() {
    switch (_coloniesState) {
      case _LoadState.loading:
        return const LoadingView(message: 'Loading colonies…');
      case _LoadState.error:
        return ErrorRetryView(
          message: _errorMessage ?? 'Something went wrong.',
          onRetry: _loadColonies,
        );
      case _LoadState.loaded:
        if (_colonies.isEmpty) {
          return const EmptyStateView(
            icon: Icons.location_city_outlined,
            title: 'No colonies yet',
            subtitle: 'Tap the + button to add the first unit.',
          );
        }
        return RefreshIndicator(
          color: AppColors.brass,
          onRefresh: _loadColonies,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _colonies.length,
            itemBuilder: (context, index) {
              final colony = _colonies[index];
              return ListTile(
                leading: const Icon(Icons.location_city_outlined, color: AppColors.brass),
                title: Text(colony, style: Theme.of(context).textTheme.titleMedium),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TypesScreen(colony: colony)),
                ),
              );
            },
          ),
        );
    }
  }
}