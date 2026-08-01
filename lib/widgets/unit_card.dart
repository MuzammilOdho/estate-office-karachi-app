import 'package:flutter/material.dart';

import '../models/unit_list_item.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

class UnitCard extends StatelessWidget {
  final UnitListItem item;
  final VoidCallback onTap;
  final bool showColonyAndType;

  const UnitCard({
    super.key,
    required this.item,
    required this.onTap,
    this.showColonyAndType = false,
  });

  @override
  Widget build(BuildContext context) {
    final unit = item.unit;
    final allottee = item.allotteeName;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
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
                ],
              ),
              const SizedBox(height: 4),
              Text(
                showColonyAndType ? '${unit.colony} · ${unit.type}' : unit.type,
                style: const TextStyle(color: AppColors.vacantGray, fontSize: 13),
              ),
              if (allottee != null && allottee.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  allottee,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}