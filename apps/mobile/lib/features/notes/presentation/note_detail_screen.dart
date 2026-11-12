import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/notes_dao.dart';
import '../../../core/database/database_provider.dart';
import 'notes_controller.dart';

final _noteProvider = StreamProvider.autoDispose.family<Note?, String>((ref, noteId) {
  final db = ref.watch(databaseProvider);
  return NotesDao(db).watchNote(noteId);
});

class NoteDetailScreen extends ConsumerStatefulWidget {
  final String noteId;

  const NoteDetailScreen({super.key, required this.noteId});

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteAsync = ref.watch(_noteProvider(widget.noteId));

    return noteAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (note) {
        if (note == null || note.deletedAt != null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Note not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(note.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.camera_alt_outlined),
                tooltip: 'Capture / Resume',
                onPressed: () {
                  context.push(
                    '/capture/${note.id}?title=${Uri.encodeComponent(note.title)}',
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Rename',
                onPressed: () => _showRenameDialog(note),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(note),
              ),
            ],
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.construction_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Timeline player and PDF view coming in M8',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Resume / View Capture'),
                    onPressed: () {
                      context.push(
                        '/capture/${note.id}?title=${Uri.encodeComponent(note.title)}',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRenameDialog(Note note) async {
    final controller = TextEditingController(text: note.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Rename Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.of(dialogCtx).pop(text);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted || newTitle == null || newTitle == note.title) return;
    await ref.read(notesNotifierProvider.notifier).updateNoteTitle(widget.noteId, newTitle);
  }

  Future<void> _confirmDelete(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Note?'),
        content: Text('Delete "${note.title}"? You can undo this from the notes list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    await ref.read(notesNotifierProvider.notifier).deleteNote(widget.noteId);
    if (mounted) {
      context.pop();
    }
  }
}
