import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/allottee_modification_model.dart';
import '../repositories/allottee_modifications_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../widgets/state_views.dart';

class AllotteeHistoryScreen extends StatefulWidget {
  final String allotteeId;
  final String allotteeName;

  const AllotteeHistoryScreen({
    super.key,
    required this.allotteeId,
    required this.allotteeName,
  });

  @override
  State<AllotteeHistoryScreen> createState() => _AllotteeHistoryScreenState();
}

enum _LoadState { loading, loaded, error }

class _AllotteeHistoryScreenState extends State<AllotteeHistoryScreen> {
  final _repository = AllotteeModificationsRepository();
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  List<AllotteeModificationModel> _history = [];

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
      final history = await _repository.getHistoryForAllottee(widget.allotteeId);
      if (!mounted) return;
      setState(() {
        _history = history;
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
      appBar: AppBar(title: Text('History · ${widget.allotteeName}')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.loading:
        return const LoadingView(message: 'Loading history…');
      case _LoadState.error:
        return ErrorRetryView(
          message: _errorMessage ?? 'Something went wrong.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        if (_history.isEmpty) {
          return const EmptyStateView(
            icon: Icons.history_outlined,
            title: 'No modifications recorded',
            subtitle: 'Changes to this allottee\'s info will appear here.',
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _history.length,
            itemBuilder: (context, index) => _ModificationCard(entry: _history[index]),
          ),
        );
    }
  }
}

class _ModificationCard extends StatelessWidget {
  final AllotteeModificationModel entry;
  const _ModificationCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.changedByName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(entry.changedAt),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const Divider(height: 20),
            for (final change in entry.changes) _DiffRow(change: change),
            if (entry.remarks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Remarks: ${entry.remarks}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
            if (entry.documentUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entry.documentUrls
                    .map((url) => _DocumentThumb(url: url))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  final FieldChange change;
  const _DiffRow({required this.change});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '${change.fieldLabel}: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: change.oldValue.isEmpty ? '(blank)' : change.oldValue,
              style: const TextStyle(
                color: AppColors.dueRed,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const TextSpan(text: '  →  '),
            TextSpan(
              text: change.newValue.isEmpty ? '(blank)' : change.newValue,
              style: const TextStyle(color: AppColors.allottedGreen),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentThumb extends StatelessWidget {
  final String url;
  const _DocumentThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    // Match the displayed 64×64 thumbnail (× device pixel ratio) so the
    // full-resolution document image isn't decoded into memory.
    final thumbPx = (64 * MediaQuery.devicePixelRatioOf(context)).ceil();

    return InkWell(
      onTap: () => showDialog(
        context: context,
        builder: (_) => Dialog(
          // Full-size on tap — intentionally no cache sizing here.
          child: InteractiveViewer(child: Image.network(url)),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          cacheWidth: thumbPx,
          cacheHeight: thumbPx,
          errorBuilder: (_, __, ___) => Container(
            width: 64,
            height: 64,
            color: AppColors.divider,
            child: const Icon(Icons.insert_drive_file_outlined, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}