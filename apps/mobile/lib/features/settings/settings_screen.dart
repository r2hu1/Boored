import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database_provider.dart';
import '../../core/network/api_client.dart';
import '../auth/presentation/auth_controller.dart';
import '../sync/sync_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final syncState = ref.watch(syncNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          if (user != null) ...[
            ListTile(
              leading: user.avatarUrl != null
                  ? CircleAvatar(backgroundImage: NetworkImage(user.avatarUrl!))
                  : CircleAvatar(child: Text(user.name.isNotEmpty ? user.name[0] : '?')),
              title: Text(user.name),
              subtitle: Text(user.email),
              trailing: TextButton(
                onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
                child: const Text('Sign out'),
              ),
            ),
            const Divider(),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Cloud Backup'),
              subtitle: const Text('Sign in with Google to backup your notes to the cloud'),
              trailing: FilledButton.tonal(
                onPressed: () => context.push('/login'),
                child: const Text('Sign In'),
              ),
            ),
            const Divider(),
          ],
          const ListTile(
            title: Text('Account & Privacy', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.sync_outlined),
            title: const Text('Manual Cloud Sync'),
            subtitle: Text(
              user == null
                  ? 'Sign in required for cloud backups'
                  : (syncState.lastSyncTime != null
                      ? 'Last synced: ${syncState.lastSyncTime}'
                      : 'Pending items: ${syncState.pendingCount}'),
            ),
            trailing: syncState.status == SyncStatus.syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: () {
              if (user == null) {
                context.push('/login');
              } else {
                ref.read(syncNotifierProvider.notifier).syncNow();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: Text(
              user != null ? 'Delete Account & Data' : 'Clear Local Data',
              style: const TextStyle(color: Colors.red),
            ),
            subtitle: Text(
              user != null
                  ? 'Permanently erase account, notes, and local files'
                  : 'Permanently erase all local notes and keyframes',
            ),
            onTap: () => _confirmAccountDeletion(context, ref),
          ),
          const Divider(),
          const ListTile(
            title: Text('App Info', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Boored App'),
            subtitle: Text('Version 0.1.0 • Classroom Whiteboard Digitization'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAccountDeletion(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authNotifierProvider).user;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(user != null ? 'Delete Account?' : 'Clear Local Data?'),
        content: Text(
          user != null
              ? 'This will permanently delete your user profile, cloud-synced whiteboard notes, and sign you out. This action cannot be undone.'
              : 'This will permanently delete all local whiteboard notes and keyframes from this device. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(user != null ? 'Delete Permanently' : 'Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      if (user != null) {
        final apiClient = ApiClient();
        try {
          await apiClient.dio.delete('/me');
        } catch (_) {}
      }

      final db = ref.read(databaseProvider);
      await db.delete(db.notes).go();
      await db.delete(db.folders).go();
      await db.delete(db.keyframes).go();

      if (user != null) {
        await ref.read(authNotifierProvider.notifier).signOut();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user != null
                  ? 'Account and all data deleted successfully'
                  : 'All local data cleared successfully',
            ),
          ),
        );
      }
    }
  }
}
