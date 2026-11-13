import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/relative_time.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.35},
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: colors.onErrorContainer,
          size: 22,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Material(
          color: isDark ? colors.surfaceContainerLow : colors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.outlineVariant.withValues(
                    alpha: isDark ? 0.25 : 0.45,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          note.title.trim().isEmpty
                              ? 'Untitled note'
                              : note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            letterSpacing: -0.2,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              relativeTime(note.updatedAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusChip(status: note.status),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final (Color color, String label) = switch (status) {
      'recording' => (Colors.orange, 'Recording'),
      'processing' => (Colors.blue, 'Processing'),
      'ready' => (Colors.green, 'Ready'),
      'failed' => (colors.error, 'Failed'),
      _ => (colors.onSurfaceVariant, status.isEmpty ? 'Unknown' : status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
