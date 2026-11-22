import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/database/app_database.dart';
import '../../notes/presentation/notes_controller.dart';
import '../../notes/presentation/widgets/create_note_dialog.dart';
import '../../notes/presentation/widgets/note_card.dart';
import 'folders_controller.dart';
import 'widgets/folder_sheet.dart';

class FolderDetailScreen extends ConsumerStatefulWidget {
  final String folderId;

  const FolderDetailScreen({super.key, required this.folderId});

  @override
  ConsumerState<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends ConsumerState<FolderDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final folderAsync = ref.watch(folderByIdProvider(widget.folderId));
    final notesAsync = ref.watch(notesInFolderProvider(widget.folderId));

    return folderAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error loading folder: $e')),
      ),
      data: (folder) {
        if (folder == null || folder.deletedAt != null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Folder not found')),
          );
        }

        return Scaffold(
          backgroundColor: colors.surface,
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(folder.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    folder.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'edit') _editFolder(folder);
                  if (val == 'delete') _deleteFolder(folder);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Edit folder'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: colors.error),
                        const SizedBox(width: 10),
                        Text('Delete folder', style: TextStyle(color: colors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: notesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (notes) {
              if (notes.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(folder.icon, style: const TextStyle(fontSize: 32)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notes in this folder',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Create or import notes into "${folder.name}"',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Note'),
                          onPressed: () => _showNewNoteOptions(context),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 88),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return NoteCard(
                    note: note,
                    onTap: () => context.push('/notes/${note.id}'),
                    onRename: () async {
                      final newTitle = await showRenameNoteSheet(
                        context,
                        currentTitle: note.title,
                      );
                      if (newTitle != null && newTitle != note.title) {
                        ref
                            .read(notesNotifierProvider.notifier)
                            .updateNoteTitle(note.id, newTitle);
                      }
                    },
                    onDelete: () async {
                      final confirmed = await showDeleteNoteSheet(
                        context,
                        noteTitle: note.title,
                      );
                      if (confirmed == true) {
                        ref
                            .read(notesNotifierProvider.notifier)
                            .deleteNote(note.id);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('"${note.title}" deleted'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () {
                                ref
                                    .read(notesNotifierProvider.notifier)
                                    .restoreNote(note.id);
                              },
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showNewNoteOptions(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Future<void> _editFolder(Folder folder) async {
    final result = await showEditFolderSheet(
      context,
      initialName: folder.name,
      initialIcon: folder.icon,
    );
    if (!mounted || result == null) return;
    ref.read(foldersNotifierProvider.notifier).updateFolder(
          folder.id,
          name: result.name,
          icon: result.icon,
        );
  }

  Future<void> _deleteFolder(Folder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text('Delete "${folder.name}"? Notes inside will be kept in your main notes list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;
    await ref.read(foldersNotifierProvider.notifier).deleteFolder(folder.id);
    if (mounted) context.pop();
  }

  void _showNewNoteOptions(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'New Note in Folder',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.videocam_rounded,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                title: const Text('Record Live'),
                subtitle: const Text('Capture whiteboard in real-time'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _createAndCaptureLive(context);
                },
              ),
              const SizedBox(height: 4),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.upload_file_rounded,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                title: const Text('Upload Video'),
                subtitle: const Text('Import a prerecorded lecture video'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _createAndImportVideo(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createAndCaptureLive(BuildContext context) async {
    final title = await showCreateNoteSheet(context);
    if (!mounted || title == null || title.isEmpty) return;

    final note = await ref
        .read(notesNotifierProvider.notifier)
        .createNote(title, folderId: widget.folderId);
    if (!mounted || note == null) return;

    context.push(
      '/capture/${note.id}?title=${Uri.encodeComponent(note.title)}',
    );
  }

  Future<void> _createAndImportVideo(BuildContext context) async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (!mounted || video == null) return;

    final title = await showCreateNoteSheet(context);
    if (!mounted || title == null || title.isEmpty) return;

    final note = await ref
        .read(notesNotifierProvider.notifier)
        .createNote(title, folderId: widget.folderId);
    if (!mounted || note == null) return;

    context.push(
      '/import/${note.id}'
      '?title=${Uri.encodeComponent(note.title)}'
      '&video=${Uri.encodeComponent(video.path)}',
    );
  }
}
