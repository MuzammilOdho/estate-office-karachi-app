import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/unit_list_item.dart';
import '../repositories/export_repository.dart';
import '../repositories/units_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/csv_export.dart';
import '../utils/fiscal_year_utils.dart';

class ExportScreen extends StatefulWidget {
  /// When opened from a specific unit's detail screen, these pre-select
  /// scope=singleUnit so staff can jump straight to "this unit's payment
  /// history" without re-searching for it.
  final String? initialUnitId;
  final String? initialUnitLabel;

  const ExportScreen({super.key, this.initialUnitId, this.initialUnitLabel});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final _exportRepository = ExportRepository();
  final _unitsRepository = UnitsRepository();

  late ExportScope _scope =
  widget.initialUnitId != null ? ExportScope.singleUnit : ExportScope.allUnits;
  late ExportPeriod _period =
  widget.initialUnitId != null ? ExportPeriod.allTime : ExportPeriod.fiscalYear;

  // Fiscal year
  late final List<String> _fyOptions = FiscalYearUtils.recentFYs(count: 8);
  late String _selectedFy = _fyOptions.first;

  // Month (last 24 months, most recent first)
  late final List<DateTime> _monthOptions = List.generate(
    24,
        (i) => DateTime(DateTime.now().year, DateTime.now().month - i, 1),
  );
  late DateTime _selectedMonth = _monthOptions.first;

  // Colony
  bool _isLoadingColonies = true;
  List<String> _colonies = [];
  String? _selectedColony;

  // Specific unit search
  final _unitSearchController = TextEditingController();
  Timer? _debounce;
  bool _isSearchingUnits = false;
  List<UnitListItem> _unitSearchResults = [];
  /// Monotonic token — drops out-of-order search responses so a slow
  /// earlier query can't overwrite the results of a newer one.
  int _unitSearchSeq = 0;
  String? _selectedUnitId;
  String _selectedUnitLabel = '';

  bool _isGenerating = false;
  String? _errorMessage;
  int? _lastRowCount;

  @override
  void initState() {
    super.initState();
    if (widget.initialUnitId != null) {
      _selectedUnitId = widget.initialUnitId;
      _selectedUnitLabel = widget.initialUnitLabel ?? '';
    }
    _loadColonies();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _unitSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadColonies() async {
    try {
      final colonies = await _unitsRepository.getColonies();
      if (!mounted) return;
      setState(() {
        _colonies = colonies;
        _isLoadingColonies = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingColonies = false);
    }
  }

  void _onUnitSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _searchUnits(query));
  }

  Future<void> _searchUnits(String query) async {
    final seq = ++_unitSearchSeq;
    if (query.trim().isEmpty) {
      setState(() => _unitSearchResults = []);
      return;
    }
    setState(() => _isSearchingUnits = true);
    try {
      final results = await _unitsRepository.searchAllUnits(query);
      if (!mounted || seq != _unitSearchSeq) return;
      setState(() => _unitSearchResults = results);
    } catch (_) {
      // Non-fatal — an empty result list is an acceptable fallback here.
    } finally {
      if (mounted && seq == _unitSearchSeq) {
        setState(() => _isSearchingUnits = false);
      }
    }
  }

  String get _periodLabel {
    switch (_period) {
      case ExportPeriod.fiscalYear:
        return 'FY $_selectedFy';
      case ExportPeriod.month:
        return DateFormat('MMMM yyyy').format(_selectedMonth);
      case ExportPeriod.allTime:
        return 'All years';
    }
  }

  String get _scopeLabel {
    switch (_scope) {
      case ExportScope.allUnits:
        return 'All units';
      case ExportScope.colony:
        return _selectedColony ?? 'Colony';
      case ExportScope.singleUnit:
        return _selectedUnitLabel.isNotEmpty ? _selectedUnitLabel : 'Unit';
    }
  }

  Future<void> _generateAndShare() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _lastRowCount = null;
    });

    try {
      final rowCount = await CsvExport.shareCsv(
        rows: _exportRepository.streamReport(
          scope: _scope,
          period: _period,
          unitId: _scope == ExportScope.singleUnit ? _selectedUnitId : null,
          colony: _scope == ExportScope.colony ? _selectedColony : null,
          fy: _period == ExportPeriod.fiscalYear ? _selectedFy : null,
          year: _period == ExportPeriod.month ? _selectedMonth.year : null,
          month: _period == ExportPeriod.month ? _selectedMonth.month : null,
        ),
        reportLabel: _scopeLabel,
        periodLabel: _periodLabel,
        onRowCount: (count) {
          // Update the row count in the UI as rows stream in.
          if (mounted) setState(() => _lastRowCount = count);
        },
      );

      if (!mounted) return;
      if (rowCount == 0) {
        setState(() {
          _errorMessage = 'No data for $_scopeLabel, $_periodLabel.';
        });
        return;
      }
      setState(() => _lastRowCount = rowCount);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is AppException ? e.message : 'Something went wrong.';
        });
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Scope', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildScopeSelector(),
            const SizedBox(height: 12),
            _buildScopeDetail(),
            const SizedBox(height: 24),
            Text('Period', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildPeriodSelector(),
            const SizedBox(height: 12),
            _buildPeriodDetail(),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateAndShare,
              icon: _isGenerating
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.ios_share_rounded),
              label: Text(_isGenerating ? 'Building report…' : 'Generate & share CSV'),
            ),
            if (_lastRowCount != null) ...[
              const SizedBox(height: 16),
              Text(
                'Report generated with $_lastRowCount row${_lastRowCount == 1 ? '' : 's'}. '
                    'Choose where to save or send it from the share sheet.',
                style: const TextStyle(color: AppColors.allottedGreen),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: AppColors.dueRed)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScopeSelector() {
    return SegmentedButton<ExportScope>(
      segments: const [
        ButtonSegment(value: ExportScope.allUnits, label: Text('All units')),
        ButtonSegment(value: ExportScope.colony, label: Text('Colony')),
        ButtonSegment(value: ExportScope.singleUnit, label: Text('One unit')),
      ],
      selected: {_scope},
      onSelectionChanged: (selection) {
        setState(() {
          _scope = selection.first;
          // "All time" only makes sense for a single unit's full history.
          if (_scope != ExportScope.singleUnit && _period == ExportPeriod.allTime) {
            _period = ExportPeriod.fiscalYear;
          }
        });
      },
    );
  }

  Widget _buildScopeDetail() {
    switch (_scope) {
      case ExportScope.allUnits:
        return const SizedBox.shrink();
      case ExportScope.colony:
        return _isLoadingColonies
            ? const LinearProgressIndicator(color: AppColors.primary)
            : DropdownButtonFormField<String>(
          initialValue: _selectedColony,
          decoration: const InputDecoration(labelText: 'Colony'),
          hint: const Text('Select colony'),
          items: _colonies
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (value) => setState(() => _selectedColony = value),
        );
      case ExportScope.singleUnit:
        return _buildUnitSearch();
    }
  }

  Widget _buildUnitSearch() {
    if (_selectedUnitId != null && _selectedUnitLabel.isNotEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          title: Text(_selectedUnitLabel),
          trailing: TextButton(
            onPressed: () => setState(() {
              _selectedUnitId = null;
              _selectedUnitLabel = '';
            }),
            child: const Text('Change'),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _unitSearchController,
          onChanged: _onUnitSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search house no, allottee name, or CNIC',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isSearchingUnits
                ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
                : null,
          ),
        ),
        if (_unitSearchResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _unitSearchResults.length,
              itemBuilder: (context, index) {
                final item = _unitSearchResults[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    title: Text(item.unit.displayLabel),
                    subtitle: Text(
                      '${item.unit.colony} · ${item.unit.type}'
                          '${item.allotteeName != null && item.allotteeName!.isNotEmpty ? ' · ${item.allotteeName}' : ''}',
                    ),
                    onTap: () => setState(() {
                      _selectedUnitId = item.unit.id;
                      _selectedUnitLabel =
                      '${item.unit.displayLabel} (${item.unit.colony})';
                      _unitSearchResults = [];
                      _unitSearchController.clear();
                    }),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPeriodSelector() {
    final segments = [
      const ButtonSegment(value: ExportPeriod.fiscalYear, label: Text('Fiscal year')),
      const ButtonSegment(value: ExportPeriod.month, label: Text('Month')),
      if (_scope == ExportScope.singleUnit)
        const ButtonSegment(value: ExportPeriod.allTime, label: Text('All time')),
    ];
    return SegmentedButton<ExportPeriod>(
      segments: segments,
      selected: {_period},
      onSelectionChanged: (selection) => setState(() => _period = selection.first),
    );
  }

  Widget _buildPeriodDetail() {
    switch (_period) {
      case ExportPeriod.fiscalYear:
        return DropdownButtonFormField<String>(
          initialValue: _selectedFy,
          decoration: const InputDecoration(labelText: 'Fiscal year'),
          items: _fyOptions
              .map((fy) => DropdownMenuItem(value: fy, child: Text('FY $fy')))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedFy = value);
          },
        );
      case ExportPeriod.month:
        return DropdownButtonFormField<DateTime>(
          initialValue: _selectedMonth,
          decoration: const InputDecoration(labelText: 'Month'),
          items: _monthOptions
              .map((m) => DropdownMenuItem(
            value: m,
            child: Text(DateFormat('MMMM yyyy').format(m)),
          ))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedMonth = value);
          },
        );
      case ExportPeriod.allTime:
        return const Text(
          'Every payment on record for this unit, oldest to newest.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        );
    }
  }
}