import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/payment_model.dart';
import '../models/unit_list_item.dart';
import '../repositories/payments_repository.dart';
import '../repositories/units_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/input_formatters.dart';
import '../widgets/payment_list.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import 'unit_detail_sheet.dart';

/// Structured, server-side search: Type/Category, House No., Allottee
/// Name, CNIC and Personal No. — each usable on its own or combined
/// (AND logic). All filtering happens on the PocketBase server, so the
/// app never downloads the estate to search it.
///
/// Results keep the register's Unit → Allotment → Payments hierarchy:
/// each card is a unit; expanding it shows the active allotment, the
/// allottee, and that allotment's payment history (paged in from the
/// server on expand, never up front).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _unitsRepository = UnitsRepository();

  final _typeController = TextEditingController();
  final _houseNoController = TextEditingController();
  final _nameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _personalNoController = TextEditingController();

  /// Monotonic token guarding against out-of-order responses: if a second
  /// search starts before the first finishes, the first result is dropped
  /// instead of overwriting the newer one.
  int _searchSeq = 0;

  bool _isSearching = false;
  bool _searchAttempted = false;
  String? _errorMessage;
  List<UnitListItem> _results = const [];
  int _totalItems = 0;

  @override
  void dispose() {
    _typeController.dispose();
    _houseNoController.dispose();
    _nameController.dispose();
    _cnicController.dispose();
    _personalNoController.dispose();
    super.dispose();
  }

  bool get _allFiltersEmpty =>
      _typeController.text.trim().isEmpty &&
      _houseNoController.text.trim().isEmpty &&
      _nameController.text.trim().isEmpty &&
      _cnicController.text.trim().isEmpty &&
      _personalNoController.text.trim().isEmpty;

  Future<void> _search() async {
    final seq = ++_searchSeq;
    if (_allFiltersEmpty) {
      setState(() {
        _errorMessage = 'Enter at least one filter, then tap Search.';
        _searchAttempted = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });
    try {
      final result = await _unitsRepository.searchFilteredUnits(
        type: _typeController.text,
        houseNo: _houseNoController.text,
        cnic: _cnicController.text,
        name: _nameController.text,
        personalNo: _personalNoController.text,
      );
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = result.items;
        _totalItems = result.totalItems;
        _searchAttempted = true;
      });
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _errorMessage = e is AppException ? e.message : 'Something went wrong.';
      });
    } finally {
      if (mounted && seq == _searchSeq) setState(() => _isSearching = false);
    }
  }

  void _clearFilters() {
    ++_searchSeq; // any in-flight response is now stale
    _typeController.clear();
    _houseNoController.clear();
    _nameController.clear();
    _cnicController.clear();
    _personalNoController.clear();
    setState(() {
      _results = const [];
      _totalItems = 0;
      _searchAttempted = false;
      _errorMessage = null;
      _isSearching = false;
    });
  }

  void _openUnitDetail(UnitListItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => UnitDetailSheet(unitId: item.unit.id),
    ).then((_) {
      // Refresh so allot/vacate/modify actions taken in the sheet are
      // reflected here — same pattern as the other list screens.
      if (mounted && _searchAttempted) _search();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search & Filter')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildFilterPanel(),
            const SizedBox(height: 20),
            _buildResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _typeController,
          decoration: const InputDecoration(
            labelText: 'Type / Category',
            hintText: 'Type A',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _houseNoController,
          decoration: const InputDecoration(
            labelText: 'House No.',
            hintText: 'House, block, or flat no',
            prefixIcon: Icon(Icons.home_outlined),
          ),
          style: AppTheme.numericData,
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Allottee Name',
            prefixIcon: Icon(Icons.person_outline),
          ),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cnicController,
          decoration: const InputDecoration(
            labelText: 'CNIC',
            hintText: '42101-1234567-1',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          style: AppTheme.numericData,
          keyboardType: TextInputType.number,
          inputFormatters: [CnicInputFormatter()],
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _personalNoController,
          decoration: const InputDecoration(
            labelText: 'Personal No.',
            prefixIcon: Icon(Icons.numbers_outlined),
          ),
          style: AppTheme.numericData,
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSearching ? null : _search,
                icon: _isSearching
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(_isSearching ? 'Searching…' : 'Search'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _clearFilters,
              child: const Text('Clear Filters'),
            ),
          ],
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(_errorMessage!, style: const TextStyle(color: AppColors.dueRed)),
        ],
      ],
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const SizedBox(height: 240, child: LoadingView(message: 'Searching…'));
    }
    if (_errorMessage != null) {
      return SizedBox(
        height: 240,
        child: ErrorRetryView(message: _errorMessage!, onRetry: _search),
      );
    }
    if (!_searchAttempted) {
      return const EmptyStateView(
        icon: Icons.filter_alt_outlined,
        title: 'Search the estate register',
        subtitle: 'Fill in any filter — they combine — and tap Search. '
            'Each result expands to its allotment and payments.',
      );
    }
    if (_results.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        subtitle: 'Try fewer or different filter values.',
      );
    }

    final capped = _totalItems > _results.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          capped
              ? '$_totalItems matches — showing the first ${_results.length}. '
                  'Refine the filters to narrow down.'
              : '${_results.length} ${_results.length == 1 ? 'unit' : 'units'} found',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 8),
        for (final item in _results)
          _ResultCard(
            key: ValueKey(item.unit.id),
            item: item,
            onOpenDetail: () => _openUnitDetail(item),
          ),
      ],
    );
  }
}

/// One search result: a unit card that expands in place to the unit's
/// active allotment, its allottee, and that allotment's payment history.
/// The payment section is only built while expanded, so its first page is
/// fetched from the server on expand rather than for every result row.
class _ResultCard extends StatefulWidget {
  final UnitListItem item;
  final VoidCallback onOpenDetail;

  const _ResultCard({
    super.key,
    required this.item,
    required this.onOpenDetail,
  });

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  final _paymentsRepository = PaymentsRepository();
  bool _expanded = false;

  static final _dateFormat = DateFormat('dd MMM yyyy');

  Future<List<PaymentModel>> _loadPaymentsPage(int page) async {
    final result = await _paymentsRepository.getHistoryForAllotment(
      widget.item.activeAllotment!.id,
      page: page,
    );
    return result.items;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final unit = item.unit;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      unit.displayLabel,
                      style: AppTheme.numericData.copyWith(fontSize: 16),
                    ),
                  ),
                  StatusBadge(isAllotted: item.isAllotted),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${unit.colony} · ${unit.type}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              if ((item.allotteeName ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.allotteeName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
              ],
              if (_expanded) ..._buildExpanded(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildExpanded(BuildContext context) {
    final item = widget.item;
    final unit = item.unit;
    final allotment = item.activeAllotment;

    return [
      const Divider(height: 24),
      // --- Unit ---
      if (unit.houseNo.isNotEmpty)
        _Row(label: 'House no', value: unit.houseNo, mono: true),
      if (unit.block.isNotEmpty) _Row(label: 'Block', value: unit.block, mono: true),
      if (unit.flatNo.isNotEmpty)
        _Row(label: 'Flat no', value: unit.flatNo, mono: true),
      _Row(label: 'Colony', value: unit.colony),
      _Row(label: 'Type', value: unit.type),
      if (allotment != null) ...[
        // --- Allotment ---
        const SizedBox(height: 12),
        Text('Allotment', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        _Row(
          label: 'Date allotted',
          value: _dateFormat.format(allotment.dateOfAllotment),
        ),
        _Row(
          label: 'Date occupied',
          value: _dateFormat.format(allotment.dateOfOccupation),
        ),
        // --- Allottee ---
        const SizedBox(height: 12),
        Text('Allottee', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        ..._allotteeRows(item),
        // --- Payments ---
        const SizedBox(height: 16),
        Text('Payments', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        PaymentList(loadPage: _loadPaymentsPage),
      ] else ...[
        const SizedBox(height: 8),
        const Text(
          'Vacant — no allotment on record.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: widget.onOpenDetail,
          icon: const Icon(Icons.open_in_full, size: 16),
          label: const Text('Open full details'),
        ),
      ),
    ];
  }

  List<Widget> _allotteeRows(UnitListItem item) {
    final rows = <Widget>[
      if ((item.allotteeName ?? '').isNotEmpty)
        _Row(label: 'Name', value: item.allotteeName!),
      if ((item.allotteeCnic ?? '').isNotEmpty)
        _Row(label: 'CNIC', value: item.allotteeCnic!, mono: true),
      if ((item.allotteePersonalNo ?? '').isNotEmpty)
        _Row(label: 'Personal No', value: item.allotteePersonalNo!, mono: true),
      if ((item.allotteeDesignation ?? '').isNotEmpty)
        _Row(label: 'Designation', value: item.allotteeDesignation!),
      if ((item.allotteeDepartment ?? '').isNotEmpty)
        _Row(label: 'Department', value: item.allotteeDepartment!),
      if ((item.allotteePhone ?? '').isNotEmpty)
        _Row(label: 'Mobile No', value: item.allotteePhone!, mono: true),
    ];
    if (rows.isEmpty) {
      // Active allotment whose allottee relation is empty (historical
      // data) — say so instead of rendering a blank section.
      rows.add(const _Row(label: 'Name', value: 'Not on record'));
    }
    return rows;
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _Row({required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: mono ? AppTheme.numericData : null),
          ),
        ],
      ),
    );
  }
}
