import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/folders_dao.dart';
import '../../../core/database/database_provider.dart';

final foldersRepositoryProvider = Provider<FoldersRepository>((ref) {
  final dao = ref.watch(foldersDaoProvider);
  return FoldersRepository(dao);
});

class FoldersRepository {
  final FoldersDao _dao;

  FoldersRepository(this._dao);

  Stream<List<Folder>> watchFolders([String? userId]) => _dao.watchAllFolders(userId);

  Future<List<Folder>> getFolders([String? userId]) => _dao.getAllFolders(userId);

  Stream<Folder?> watchFolder(String folderId) => _dao.watchFolder(folderId);

  Future<Folder?> getFolder(String folderId) => _dao.getFolderById(folderId);

  Future<Folder> createFolder({
    required String userId,
    required String name,
    String icon = '📁',
  }) =>
      _dao.createFolder(userId: userId, name: name, icon: icon);

  Future<void> updateFolder(String folderId, {String? name, String? icon}) =>
      _dao.updateFolder(folderId, name: name, icon: icon);

  Future<void> deleteFolder(String folderId) => _dao.deleteFolder(folderId);

  Stream<int> watchNoteCount(String folderId) => _dao.watchNoteCountForFolder(folderId);
}
