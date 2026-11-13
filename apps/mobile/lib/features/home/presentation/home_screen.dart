import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authNotifierProvider).user;
    final notesState = ref.watch(notesNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boored'),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2E384D)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    Icons.search,
                    size: 20,
                    color: isDark
                        ? const Color(0xFF8B9BB4)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search notes...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (query) {
                        ref.read(notesNotifierProvider.notifier).search(query);
                        setState(() {});
                      },
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        ref.read(notesNotifierProvider.notifier).clearSearch();
                        setState(() {});
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.cancel,
                          size: 18,
                          color: isDark
                              ? const Color(0xFF8B9BB4)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildBody(context, notesState, theme)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
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

  Future<void> _showCreateDialog(BuildContext context) async {
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
}
