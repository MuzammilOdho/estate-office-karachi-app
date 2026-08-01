import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LoadingView extends StatelessWidget {
  final String? message;
  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.brass),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: const TextStyle(color: AppColors.vacantGray)),
          ],
        ],
      ),
    );
  }
}

/// Shown for network/server failures — spec §7: "one clear message" plus
/// the ability to retry, never a raw exception or blank screen.
class ErrorRetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorRetryView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.dueRed),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkNavy, fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyStateView({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.vacantGray),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.vacantGray),
              ),
            ],
          ],
        ),
      ),
    );
  }
}