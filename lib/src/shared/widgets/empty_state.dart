import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxHeight < 180;
        final veryTight = constraints.maxHeight < 130;
        return Center(
          child: Padding(
            padding: EdgeInsets.all(tight ? AppSpacing.sm : AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: tight ? 32 : 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                SizedBox(height: tight ? AppSpacing.xs : AppSpacing.md),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (!veryTight) ...[
                  SizedBox(height: tight ? 2 : AppSpacing.xs + 2),
                  Text(
                    message,
                    maxLines: tight ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
