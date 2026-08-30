import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Takes the already-computed allotted/vacant fact as a plain bool —
/// there's no stored status string anywhere in the app to read instead.
class StatusBadge extends StatelessWidget {
  final bool isAllotted;

  const StatusBadge({super.key, required this.isAllotted});

  @override
  Widget build(BuildContext context) {
    final color = isAllotted ? AppColors.allottedGreen : AppColors.textSecondary;
    final label = isAllotted ? 'Allotted' : 'Vacant';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}