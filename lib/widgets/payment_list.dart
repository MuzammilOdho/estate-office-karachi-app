import 'package:flutter/material.dart';

import '../models/payment_model.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import 'payment_tile.dart';

/// A payment history with auto-load-more pagination.
///
/// Both the unit detail sheet (current allotment) and the allotment
/// detail screen (read-only historical view) render a unit's payment
/// history. They used to each fetch the entire history up front and
/// render every tile; long-occupied units can have 200+ payments, so
/// that blocked first paint and held every tile in memory.
///
/// This widget renders the first page immediately and fetches the next
/// page automatically as the user scrolls near the bottom — preserving
/// the "I can scroll through all history" feel while keeping first paint
/// fast and memory bounded to ~1 page.
///
/// It renders as a [Column] (it lives inside a parent scroll view) and
/// detects "near bottom" by listening to the *ancestor* scroll via a
/// [NotificationListener] — no [ScrollController] coupling, no nested
/// scroll views. [loadPage] is `page -> Future<List<PaymentModel>>`,
/// expected to throw [AppException] on failure (handled inline).
/// [showAmountDue] is forwarded to [PaymentTile].
class PaymentList extends StatefulWidget {
  final Future<List<PaymentModel>> Function(int page) loadPage;
  final bool showAmountDue;

  const PaymentList({
    super.key,
    required this.loadPage,
    this.showAmountDue = false,
  });

  @override
  State<PaymentList> createState() => _PaymentListState();
}

class _PaymentListState extends State<PaymentList> {
  static const _threshold = 0.85;

  List<PaymentModel> _items = [];
  int _nextPage = 1;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _firstLoadFailed = false;
  String? _loadMoreError;

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  void _onAncestorScroll(ScrollNotification n) {
    if (!_hasMore || _isLoading) return;
    // Only react to the nearest scrollable's overscroll/metrics, and
    // only once we're far enough down to have meaningful extent.
    if (n is ScrollUpdateNotification && n.metrics.maxScrollExtent > 0) {
      if (n.metrics.pixels >= n.metrics.maxScrollExtent * _threshold) {
        _loadNext();
      }
    }
  }

  Future<void> _loadNext() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _loadMoreError = null;
    });
    try {
      final page = await widget.loadPage(_nextPage);
      if (!mounted) return;
      setState(() {
        // An empty/short page means the server has nothing more.
        _items = [..._items, ...page];
        _nextPage++;
        _hasMore = page.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _firstLoadFailed = _items.isEmpty;
        _loadMoreError = e is AppException ? e.message : 'Something went wrong.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        _onAncestorScroll(n);
        return false; // don't consume — let the parent scroll normally
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_firstLoadFailed) ...[
            Text(
              _loadMoreError ?? 'Something went wrong.',
              style: const TextStyle(color: AppColors.dueRed),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _isLoading ? null : _loadNext,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ] else ...[
            for (final p in _items)
              PaymentTile(payment: p, showAmountDue: widget.showAmountDue),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.brass),
                  ),
                ),
              )
            else if (_loadMoreError != null) ...[
              Text(
                _loadMoreError!,
                style: const TextStyle(color: AppColors.dueRed, fontSize: 13),
              ),
              TextButton.icon(
                onPressed: _loadNext,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ]
            // When there are no more pages and we've loaded at least one,
            // show a quiet "no more" hint. If the first page itself was
            // empty, the caller renders its own "no payments yet" message.
            else if (!_hasMore && _items.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    'No more payments',
                    style: TextStyle(color: AppColors.vacantGray, fontSize: 13),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
