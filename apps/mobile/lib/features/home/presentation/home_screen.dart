import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../notes/presentation/notes_controller.dart';
import '../../notes/presentation/widgets/note_card.dart';
import '../../notes/presentation/widgets/create_note_dialog.dart';
import '../../sync/sync_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _closeSearch() {
    setState(() => _isSearching = false);
    _searchController.clear();
    ref.read(notesNotifierProvider.notifier).clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authNotifierProvider).user;
    final notesState = ref.watch(notesNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  border: InputBorder.none,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(notesNotifierProvider.notifier)
                                .clearSearch();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (query) {
                  ref.read(notesNotifierProvider.notifier).search(query);
                  setState(() {});
                },
              )
            : const Text('Boored'),
        centerTitle: false,
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _closeSearch,
              )
            : null,
        actions: [
          if (!_isSearching)
            Consumer(
              builder: (ctx, ref, _) {
                final syncState = ref.watch(syncNotifierProvider);
                if (syncState.status == SyncStatus.syncing) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                return IconButton(
                  icon: Badge(
                    isLabelVisible: syncState.pendingCount > 0,
                    label: Text('${syncState.pendingCount}'),
                    child: const Icon(Icons.sync),
                  ),
                  tooltip: 'Sync changes',
                  onPressed: () {
                    ref.read(syncNotifierProvider.notifier).syncNow();
                  },
                );
              },
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () => setState(() => _isSearching = true),
            ),
          if (!_isSearching && user != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'settings') {
                  context.push('/settings');
                } else if (value == 'sign_out') {
                  ref.read(authNotifierProvider.notifier).signOut();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: theme.textTheme.titleSmall),
                      Text(user.email, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 20),
                      SizedBox(width: 8),
                      Text('Settings'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'sign_out',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20),
                      SizedBox(width: 8),
                      Text('Sign out'),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: user.avatarUrl != null
                    ? CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(user.avatarUrl!),
                      )
                    : CircleAvatar(
                        radius: 16,
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: PopScope(
        canPop: !_isSearching,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _isSearching) {
            _closeSearch();
          }
        },
        child: _buildBody(context, notesState, theme),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewNoteOptions(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NotesState notesState,
    ThemeData theme,
  ) {
    if (notesState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notesState.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                notesState.errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    if (notesState.notes.isEmpty) {
      final isSearching = notesState.searchQuery != null;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSearching ? Icons.search_off : Icons.note_add_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isSearching ? 'No notes match your search' : 'No notes yet',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                isSearching
                    ? 'Try a different search term'
                    : 'Tap + to create your first note',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      itemCount: notesState.notes.length,
      itemBuilder: (context, index) {
        final note = notesState.notes[index];
        return NoteCard(
          note: note,
          onTap: () {
            context.push('/notes/${note.id}');
          },
          onDelete: () {
            ref.read(notesNotifierProvider.notifier).deleteNote(note.id);
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
          },
        );
      },
    );
  }

  void _showNewNoteOptions(BuildContext context) {
    final theme = Theme.of(context);
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
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'New Note',
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
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.videocam_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
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
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.upload_file_rounded,
                    color: theme.colorScheme.onTertiaryContainer,
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
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const CreateNoteDialog(),
    );
    if (!mounted || title == null || title.isEmpty) return;

    final note = await ref
        .read(notesNotifierProvider.notifier)
        .createNote(title);
    if (!mounted || note == null) return;

    if (context.mounted) {
      context.push(
        '/capture/${note.id}?title=${Uri.encodeComponent(note.title)}',
      );
    }
  }

  Future<void> _createAndImportVideo(BuildContext context) async {
    // 1. Pick video first so we don't create a note if user cancels
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (!mounted || video == null) return;

    // 2. Ask for title
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const CreateNoteDialog(),
    );
    if (!mounted || title == null || title.isEmpty) return;

    // 3. Create note
    final note = await ref
        .read(notesNotifierProvider.notifier)
        .createNote(title);
    if (!mounted || note == null) return;

    // 4. Navigate to import processing screen
    if (context.mounted) {
      context.push(
        '/import/${note.id}'
        '?title=${Uri.encodeComponent(note.title)}'
        '&video=${Uri.encodeComponent(video.path)}',
      );
    }
  }
}
