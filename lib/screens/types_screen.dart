import 'package:flutter/material.dart';

import '../repositories/units_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../widgets/state_views.dart';
import 'units_screen.dart';

class TypesScreen extends StatefulWidget {
  final String colony;
  const TypesScreen({super.key, required this.colony});

  @override
  State<TypesScreen> createState() => _TypesScreenState();
}

enum _LoadState { loading, loaded, error }

class _TypesScreenState extends State<TypesScreen> {
  final _unitsRepository = UnitsRepository();
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  List<String> _types = [];

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
      final types = await _unitsRepository.getTypesForColony(widget.colony);
      if (!mounted) return;
      setState(() {
        _types = types;
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
      appBar: AppBar(title: Text(widget.colony)),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.loading:
        return const LoadingView(message: 'Loading types…');
      case _LoadState.error:
        return ErrorRetryView(
          message: _errorMessage ?? 'Something went wrong.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        if (_types.isEmpty) {
          return const EmptyStateView(
            icon: Icons.category_outlined,
            title: 'No unit types here yet',
          );
        }
        return RefreshIndicator(
          color: AppColors.brass,
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _types.length,
            itemBuilder: (context, index) {
              final type = _types[index];
              return ListTile(
                leading: const Icon(Icons.category_outlined, color: AppColors.brass),
                title: Text(type, style: Theme.of(context).textTheme.titleMedium),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UnitsScreen(colony: widget.colony, type: type),
                  ),
                ),
              );
            },
          ),
        );
    }
  }
}