import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              syncState.lastSyncTime != null
                  ? 'Last synced: ${syncState.lastSyncTime}'
                  : 'Pending items: ${syncState.pendingCount}',
            ),
            trailing: syncState.status == SyncStatus.syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: () {
              ref.read(syncNotifierProvider.notifier).syncNow();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account & Data', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Permanently erase account, notes, and local files'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your user profile, cloud-synced whiteboard notes, and sign you out. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
      }
    }
  }
}
