import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../folders/presentation/folders_controller.dart';
import '../../folders/presentation/widgets/folder_card.dart';
import '../../folders/presentation/widgets/folder_sheet.dart';
import '../../notes/presentation/notes_controller.dart';
import '../../notes/presentation/widgets/create_note_dialog.dart';
import '../../notes/presentation/widgets/note_card.dart';
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
    final colors = theme.colorScheme;
    final user = ref.watch(authNotifierProvider).user;
    final notesState = ref.watch(notesNotifierProvider);
    final foldersState = ref.watch(foldersNotifierProvider);

    return Scaffold(
      backgroundColor: colors.surface,
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
            : const Text('Boored', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _closeSearch,
              )
            : null,
        actions: [
          if (!_isSearching) ...[
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
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search notes',
              onPressed: () => setState(() => _isSearching = true),
            ),
            if (user != null)
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: user.avatarUrl != null
                      ? CircleAvatar(
                          radius: 16,
                          backgroundImage: NetworkImage(user.avatarUrl!),
                        )
                      : CircleAvatar(
                          radius: 16,
                          backgroundColor: colors.primaryContainer,
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: colors.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
              ),
          ],
        ],
      ),
      body: PopScope(
        canPop: !_isSearching,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _isSearching) {
            _closeSearch();
          }
        },
        child: CustomScrollView(
          slivers: [
            // 1. Folders Section (Only when not searching)
            if (!_isSearching) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Folders',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New Folder'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _createFolder(context),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 104,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: foldersState.folders.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      // First item is "+ New Folder" action card
                      if (index == 0) {
                        return Material(
                          color: colors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => _createFolder(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 110,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colors.outlineVariant.withValues(alpha: 0.4),
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.create_new_folder_outlined,
                                    size: 26,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'New Folder',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      final folder = foldersState.folders[index - 1];
                      return FolderCard(
                        folder: folder,
                        onTap: () => context.push('/folders/${folder.id}'),
                        onEdit: () => _editFolder(context, folder),
                        onDelete: () => _deleteFolder(context, folder),
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 16),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'All Notes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],

            // 2. Notes Section
            _buildNotesList(context, notesState, theme, colors),

            // Bottom padding for FAB
            const SliverToBoxAdapter(
              child: SizedBox(height: 88),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewNoteOptions(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNotesList(
    BuildContext context,
    NotesState notesState,
    ThemeData theme,
    ColorScheme colors,
  ) {
    if (notesState.isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (notesState.errorMessage != null) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: colors.error),
                const SizedBox(height: 16),
                Text(
                  notesState.errorMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (notesState.notes.isEmpty) {
      final isSearching = notesState.searchQuery != null;
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSearching ? Icons.search_off : Icons.note_add_outlined,
                  size: 56,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.5),
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
                      : 'Tap + to create your first whiteboard note',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final note = notesState.notes[index];
          return NoteCard(
            note: note,
            onTap: () {
              context.push('/notes/${note.id}');
            },
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
                ref.read(notesNotifierProvider.notifier).deleteNote(note.id);
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
        childCount: notesState.notes.length,
      ),
    );
  }

  Future<void> _createFolder(BuildContext context) async {
    final result = await showCreateFolderSheet(context);
    if (!mounted || result == null) return;
    await ref.read(foldersNotifierProvider.notifier).createFolder(
          name: result.name,
          icon: result.icon,
        );
  }

  Future<void> _editFolder(BuildContext context, dynamic folder) async {
    final result = await showEditFolderSheet(
      context,
      initialName: folder.name,
      initialIcon: folder.icon,
    );
    if (!mounted || result == null) return;
    await ref.read(foldersNotifierProvider.notifier).updateFolder(
          folder.id,
          name: result.name,
          icon: result.icon,
        );
  }

  Future<void> _deleteFolder(BuildContext context, dynamic folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text('Delete "${folder.name}"? Notes inside will remain in All Notes.'),
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
        .createNote(title);
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
        .createNote(title);
    if (!mounted || note == null) return;

    context.push(
      '/import/${note.id}'
      '?title=${Uri.encodeComponent(note.title)}'
      '&video=${Uri.encodeComponent(video.path)}',
    );
  }
}
