import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../capture/data/keyframe_policy.dart';
import '../../../folders/presentation/folders_controller.dart';

final notePreviewTextProvider =
    StreamProvider.family<String?, String>((ref, noteId) {
  final dao = ref.watch(keyframesDaoProvider);
  return dao.watchKeyframesForNote(noteId).map((keyframes) {
    for (final kf in keyframes) {
      final text = kf.extractedText?.trim();
      if (text != null && text.isNotEmpty) {
        return text.replaceAll('\n', ' ');
      }
    }
    return null;
  });
});

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

  void _showNoteActions(BuildContext context, ColorScheme colors) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (onRename != null)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Rename note'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onRename?.call();
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: colors.error),
                title: Text('Delete note', style: TextStyle(color: colors.error)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Check if this note belongs to a folder
    final folderAsync = note.folderId != null
        ? ref.watch(folderByIdProvider(note.folderId!))
        : null;

    final previewTextAsync = ref.watch(notePreviewTextProvider(note.id));
    final previewText = previewTextAsync.asData?.value;

    final (statusIcon, statusLabel, isHighlight) = switch (note.status) {
      'recording' => (Icons.videocam_rounded, 'Recording', true),
      'processing' => (Icons.sync_rounded, 'Processing', true),
      'ready' => (Icons.file_open, 'Ready', false),
      'failed' => (Icons.error_outline_rounded, 'Failed', true),
      _ => (Icons.description_rounded, note.status, false),
    };

    final String subtitleText;
    if (isHighlight) {
      subtitleText = switch (note.status) {
        'recording' =>
          'Recording in progress • ${_formatDuration(note.durationMs ?? 0)}',
        'processing' => 'Processing whiteboard keyframes...',
        'failed' => 'Processing failed • Tap to view',
        _ => statusLabel,
      };
    } else if (previewText != null && previewText.isNotEmpty) {
      subtitleText = previewText;
    } else {
      final folderName = folderAsync?.asData?.value?.name;
      if (folderName != null && folderName.isNotEmpty) {
        subtitleText = '$folderName • Updated ${relativeTime(note.updatedAt)}';
      } else if (note.durationMs != null && note.durationMs! > 0) {
        subtitleText =
            '${_formatDuration(note.durationMs!)} • Updated ${relativeTime(note.updatedAt)}';
      } else {
        subtitleText = 'Whiteboard note • Updated ${relativeTime(note.updatedAt)}';
      }
    }

    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.35},
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: colors.onErrorContainer,
          size: 24,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            onTap: onTap,
            onLongPress: () => _showNoteActions(context, colors),
            borderRadius: BorderRadius.circular(28),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Circular Icon Badge (Matches the reference image)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isHighlight && note.status == 'recording'
                          ? colors.errorContainer.withValues(alpha: 0.7)
                          : colors.surfaceContainerHigh,
                    ),
                    child: Icon(
                      isHighlight ? statusIcon : Icons.auto_awesome_outlined,
                      color: isHighlight && note.status == 'recording'
                          ? colors.onErrorContainer
                          : (isHighlight ? colors.primary : colors.onSurface),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Middle: Title & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title.trim().isEmpty
                              ? 'Untitled note'
                              : note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.5,
                            letterSpacing: -0.2,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isHighlight && note.status == 'recording'
                                ? colors.error
                                : colors.onSurfaceVariant,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Right: Chevron right arrow
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 24,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.65),
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
