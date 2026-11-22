import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../folders/presentation/folders_controller.dart';

class NoteCard extends ConsumerWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onRename;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    this.onRename,
  });

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Check if this note belongs to a folder
    final folderAsync = note.folderId != null
        ? ref.watch(folderByIdProvider(note.folderId!))
        : null;

    final (statusIcon, statusLabel, isHighlight) = switch (note.status) {
      'recording' => (Icons.videocam_rounded, 'Recording', true),
      'processing' => (Icons.sync_rounded, 'Processing', true),
      'ready' => (Icons.check_rounded, 'Ready', false),
      'failed' => (Icons.error_outline_rounded, 'Failed', true),
      _ => (Icons.description_rounded, note.status, false),
    };

    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.35},
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  // Leading Board Icon (Material 3 container)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isHighlight && note.status == 'recording'
                          ? colors.errorContainer.withValues(alpha: 0.7)
                          : colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      statusIcon,
                      color: isHighlight && note.status == 'recording'
                          ? colors.onErrorContainer
                          : colors.onSecondaryContainer,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Main Text Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title.trim().isEmpty ? 'Untitled note' : note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // Folder Badge if in a folder
                            if (folderAsync != null)
                              folderAsync.when(
                                data: (folder) {
                                  if (folder == null) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            folder.icon,
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            folder.name,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                loading: () => const SizedBox.shrink(),
                                error: (_, _) => const SizedBox.shrink(),
                              ),

                            // Relative Time
                            Text(
                              relativeTime(note.updatedAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),

                            // Duration (if available)
                            if (note.durationMs != null && note.durationMs! > 0) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '•',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.timer_outlined,
                                size: 12,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatDuration(note.durationMs!),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],

                            // Active status badge (recording/processing)
                            if (isHighlight) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '•',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                statusLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: note.status == 'recording' || note.status == 'failed'
                                      ? colors.error
                                      : colors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Popup Menu
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (val) {
                      if (val == 'rename') onRename?.call();
                      if (val == 'delete') onDelete();
                    },
                    itemBuilder: (ctx) => [
                      if (onRename != null)
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 16),
                              SizedBox(width: 10),
                              Text('Rename'),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 16, color: colors.error),
                            const SizedBox(width: 10),
                            Text('Delete', style: TextStyle(color: colors.error)),
                          ],
                        ),
                      ),
                    ],
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
