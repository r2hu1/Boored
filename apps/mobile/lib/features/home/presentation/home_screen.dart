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

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final AnimationController _fabAnimationController;
  late final Animation<double> _expandAnimation;
  bool _isFabOpen = false;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      value: 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
      parent: _fabAnimationController,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _closeSearch() {
    _searchController.clear();
    ref.read(notesNotifierProvider.notifier).clearSearch();
    setState(() {});
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    });
  }

  void _closeFab() {
    if (_isFabOpen) {
      setState(() {
        _isFabOpen = false;
        _fabAnimationController.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = ref.watch(authNotifierProvider).user;
    final notesState = ref.watch(notesNotifierProvider);
    final foldersState = ref.watch(foldersNotifierProvider);
    final isSearching = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Boored', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
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
      ),
      body: PopScope(
        canPop: !isSearching && !_isFabOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_isFabOpen) {
            _closeFab();
          } else if (isSearching) {
            _closeSearch();
          }
        },
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // Official Material 3 SearchBar above folders section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SearchBar(
                      controller: _searchController,
                      hintText: 'Search notes...',
                      leading: const Icon(Icons.search),
                      trailing: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _closeSearch,
                          ),
                      ],
                      elevation: const WidgetStatePropertyAll<double>(0),
                      backgroundColor: WidgetStatePropertyAll<Color>(
                        colors.surfaceContainerHigh,
                      ),
                      onChanged: (query) {
                        ref.read(notesNotifierProvider.notifier).search(query);
                        setState(() {});
                      },
                    ),
                  ),
                ),

                // 1. Folders Section (Only when not searching)
                if (!isSearching) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        'Folders',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (foldersState.folders.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 186,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: foldersState.folders.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final folder = foldersState.folders[index];
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
                  ],
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
            if (_isFabOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeFab,
                  child: FadeTransition(
                    opacity: _expandAnimation,
                    child: ColoredBox(
                      color: colors.scrim.withValues(alpha: 0.32),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _buildSpeedDial(context, theme, colors),
    );
  }

  Widget _buildSpeedDial(
    BuildContext context,
    ThemeData theme,
    ColorScheme colors,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedBuilder(
          animation: _expandAnimation,
          builder: (context, child) {
            if (_expandAnimation.value == 0.0) {
              return const SizedBox.shrink();
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildSpeedDialItem(
                  context: context,
                  theme: theme,
                  colors: colors,
                  label: 'New Folder',
                  icon: Icons.create_new_folder_rounded,
                  heroTag: 'fab_new_folder',
                  color: colors.tertiaryContainer,
                  iconColor: colors.onTertiaryContainer,
                  onTap: () => _createFolder(context),
                  delayFraction: 0.3,
                ),
                const SizedBox(height: 12),
                _buildSpeedDialItem(
                  context: context,
                  theme: theme,
                  colors: colors,
                  label: 'Upload Video',
                  icon: Icons.upload_file_rounded,
                  heroTag: 'fab_upload_video',
                  color: colors.secondaryContainer,
                  iconColor: colors.onSecondaryContainer,
                  onTap: () => _createAndImportVideo(context),
                  delayFraction: 0.15,
                ),
                const SizedBox(height: 12),
                _buildSpeedDialItem(
                  context: context,
                  theme: theme,
                  colors: colors,
                  label: 'Record Live',
                  icon: Icons.videocam_rounded,
                  heroTag: 'fab_record_live',
                  color: colors.primaryContainer,
                  iconColor: colors.onPrimaryContainer,
                  onTap: () => _createAndCaptureLive(context),
                  delayFraction: 0.0,
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
        FloatingActionButton(
          heroTag: 'fab_main',
          onPressed: _toggleFab,
          child: AnimatedRotation(
            turns: _isFabOpen ? 0.125 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedDialItem({
    required BuildContext context,
    required ThemeData theme,
    required ColorScheme colors,
    required String label,
    required IconData icon,
    required String heroTag,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    required double delayFraction,
  }) {
    final itemAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Interval(delayFraction, 1.0, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: itemAnimation,
      child: ScaleTransition(
        scale: itemAnimation,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                _closeFab();
                onTap();
              },
              child: Material(
                color: colors.surfaceContainerHigh,
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FloatingActionButton.small(
              heroTag: heroTag,
              backgroundColor: color,
              foregroundColor: iconColor,
              elevation: 2,
              onPressed: () {
                _closeFab();
                onTap();
              },
              child: Icon(icon),
            ),
          ],
        ),
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
    final name = await showCreateFolderSheet(context);
    if (!mounted || name == null) return;
    await ref.read(foldersNotifierProvider.notifier).createFolder(
          name: name,
        );
  }

  Future<void> _editFolder(BuildContext context, dynamic folder) async {
    final name = await showEditFolderSheet(
      context,
      initialName: folder.name,
    );
    if (!mounted || name == null) return;
    await ref.read(foldersNotifierProvider.notifier).updateFolder(
          folder.id,
          name: name,
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
