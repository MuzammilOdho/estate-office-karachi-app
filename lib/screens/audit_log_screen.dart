import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/audit_log_entry.dart';
import '../repositories/audit_log_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../widgets/state_views.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

enum _LoadState { loading, loaded, error }

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _repository = AuditLogRepository();
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  List<AuditLogEntry> _entries = [];

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
      final entries = await _repository.getRecent();
      if (!mounted) return;
      setState(() {
        _entries = entries;
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

  IconData _iconFor(String action) {
    switch (action) {
      case 'unit_allotted':
        return Icons.key_outlined;
      case 'unit_vacated':
        return Icons.logout;
      case 'payment_added':
        return Icons.receipt_long_outlined;
      case 'allottee_modified':
        return Icons.edit_note_outlined;
      default:
        return Icons.history_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.loading:
        return const LoadingView(message: 'Loading activity…');
      case _LoadState.error:
        return ErrorRetryView(
          message: _errorMessage ?? 'Something went wrong.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        if (_entries.isEmpty) {
          return const EmptyStateView(
            icon: Icons.history_outlined,
            title: 'No activity yet',
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final entry = _entries[index];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(_iconFor(entry.action), color: AppColors.primary),
                  title: Text(entry.summary),
                  subtitle: Text(
                    '${entry.performedByName} · '
                        '${DateFormat('dd MMM yyyy, hh:mm a').format(entry.performedAt)}',
                  ),
                ),
              );
            },
          ),
        );
    }
  }
}