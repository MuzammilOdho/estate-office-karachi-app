import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../repositories/allotments_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../widgets/state_views.dart';
import 'allotment_detail_screen.dart';

class UnitAllotmentHistoryScreen extends StatefulWidget {
  final String unitId;
  final String unitLabel;

  const UnitAllotmentHistoryScreen({
    super.key,
    required this.unitId,
    required this.unitLabel,
  });

  @override
  State<UnitAllotmentHistoryScreen> createState() =>
      _UnitAllotmentHistoryScreenState();
}

enum _LoadState { loading, loaded, error }

class _UnitAllotmentHistoryScreenState extends State<UnitAllotmentHistoryScreen> {
  final _allotmentsRepository = AllotmentsRepository();

  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  List<AllotmentWithAllottee> _items = [];

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
      final items =
          await _allotmentsRepository.getAllAllotmentsForUnit(widget.unitId);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('History · ${widget.unitLabel}')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.loading:
        return const LoadingView(message: 'Loading allotment history…');
      case _LoadState.error:
        return ErrorRetryView(
          message: _errorMessage ?? 'Something went wrong.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        if (_items.isEmpty) {
          return const EmptyStateView(
            icon: Icons.history_outlined,
            title: 'This unit has never been allotted',
          );
        }
        return RefreshIndicator(
          color: AppColors.brass,
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _items.length,
            itemBuilder: (context, index) =>
                _AllotmentCard(item: _items[index]),
          ),
        );
    }
  }
}

class _AllotmentCard extends StatelessWidget {
  final AllotmentWithAllottee item;
  const _AllotmentCard({required this.item});

  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final allotment = item.allotment;
    final allottee = item.allottee;
    final isActive = allotment.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(allottee?.name ?? '(allottee record not found)'),
        subtitle: Text(
          isActive
              ? 'Since ${_dateFormat.format(allotment.dateOfAllotment)} · Current'
              : '${_dateFormat.format(allotment.dateOfAllotment)} – '
                  '${allotment.dateOfVacancy != null ? _dateFormat.format(allotment.dateOfVacancy!) : '?'}',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: (isActive ? AppColors.allottedGreen : AppColors.vacantGray)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isActive ? 'Current' : 'Vacated',
            style: TextStyle(
              color: isActive ? AppColors.allottedGreen : AppColors.vacantGray,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        onTap: allottee == null
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AllotmentDetailScreen(
                      allotment: allotment,
                      allottee: allottee,
                    ),
                  ),
                ),
      ),
    );
  }
}
