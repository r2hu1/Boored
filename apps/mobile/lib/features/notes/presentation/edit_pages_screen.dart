import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/daos/keyframes_dao.dart';
import '../../../core/database/daos/notes_dao.dart';
import '../../capture/data/lecturer_removal_processor.dart';
import '../../capture/data/mlkit_recognition_engine.dart';
import '../../capture/data/mlkit_segmentation_engine.dart';
import '../../capture/data/opencv_service.dart';
import '../../capture/data/session_finalizer.dart';

final _editPagesKeyframesProvider = StreamProvider.autoDispose
    .family<List<Keyframe>, String>((ref, noteId) {
      final db = ref.watch(databaseProvider);
      return KeyframesDao(db).watchKeyframesForNote(noteId);
    });

class EditPagesScreen extends ConsumerStatefulWidget {
  final String noteId;
  final String noteTitle;

  const EditPagesScreen({
    super.key,
    required this.noteId,
    required this.noteTitle,
  });

  @override
  ConsumerState<EditPagesScreen> createState() => _EditPagesScreenState();
}

class _EditPagesScreenState extends ConsumerState<EditPagesScreen> {
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;

  void _toggleSelectAll(List<Keyframe> keyframes) {
    setState(() {
      if (_selectedIds.length == keyframes.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.clear();
        _selectedIds.addAll(keyframes.map((k) => k.id));
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected(List<Keyframe> allKeyframes) async {
    if (_selectedIds.isEmpty) return;

    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count Page${count > 1 ? 's' : ''}?'),
        content: Text(
          count == allKeyframes.length
              ? 'Deleting all pages will empty this note. Your timeline and PDFs will be updated.'
              : 'These $count page(s) will be removed from your timeline, document PDF, and clean copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final db = ref.read(databaseProvider);
      final keyframesDao = KeyframesDao(db);

      // 1. Delete selected records from DB
      await keyframesDao.deleteKeyframes(_selectedIds.toList());

      // 2. Re-index remaining keyframes (0, 1, 2...)
      await keyframesDao.reindexKeyframes(widget.noteId);

      // 3. Regenerate PDFs from remaining keyframes
      final finalizer = SessionFinalizer(
        notesDao: NotesDao(db),
        keyframesDao: keyframesDao,
        recognitionEngine: MLKitRecognitionEngine(),
        lecturerRemovalProcessor: LecturerRemovalProcessor(
          segmenter: MLKitSegmentationEngine(),
          openCVService: OpenCVService(),
        ),
      );
      await finalizer.regeneratePdfsAfterDeletion(widget.noteId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $count page${count > 1 ? 's' : ''}')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error deleting pages: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSinglePageOptions(Keyframe kf, List<Keyframe> allKeyframes) {
    final isSelected = _selectedIds.contains(kf.id);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined),
                      const SizedBox(width: 10),
                      Text(
                        'Page ${kf.index + 1}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(kf.timestampMs / 1000).toStringAsFixed(1)}s',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(isSelected ? 'Deselect Page' : 'Select Page'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleSelection(kf.id);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.fullscreen),
                  title: const Text('View Fullscreen'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openFullscreen(kf);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Delete This Page',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedIds.clear();
                      _selectedIds.add(kf.id);
                    });
                    _deleteSelected(allKeyframes);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFullscreen(Keyframe kf) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              'Page ${kf.index + 1}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(
                File(kf.imagePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image,
                  size: 64,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyframesAsync = ref.watch(
      _editPagesKeyframesProvider(widget.noteId),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return keyframesAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('Edit Pages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Edit Pages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        body: Center(child: Text('Error: $e')),
      ),
      data: (keyframes) {
        final allSelected =
            keyframes.isNotEmpty && _selectedIds.length == keyframes.length;
        final hasSelection = _selectedIds.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              hasSelection
                  ? '${_selectedIds.length} Selected'
                  : 'Edit Pages (${keyframes.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            actions: [
              if (keyframes.isNotEmpty)
                IconButton(
                  icon: Icon(
                    allSelected ? Icons.deselect : Icons.select_all,
                  ),
                  tooltip: allSelected ? 'Deselect All' : 'Select All',
                  onPressed: () => _toggleSelectAll(keyframes),
                ),
              if (hasSelection)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete Selected',
                  onPressed: _isProcessing
                      ? null
                      : () => _deleteSelected(keyframes),
                ),
            ],
          ),
          body: _isProcessing
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Updating PDFs & timeline...'),
                    ],
                  ),
                )
              : keyframes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.layers_clear_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No pages in this note',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: keyframes.length,
                  itemBuilder: (context, i) {
                    final kf = keyframes[i];
                    final isSelected = _selectedIds.contains(kf.id);

                    return InkWell(
                      onTap: () => _toggleSelection(kf.id),
                      onLongPress: () => _showSinglePageOptions(kf, keyframes),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : (isDark
                                      ? const Color(0xFF2E384D)
                                      : const Color(0xFFE2E8F0)),
                            width: isSelected ? 2.5 : 1,
                          ),
                          color: isDark
                              ? const Color(0xFF1E2433)
                              : Colors.white,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            // Page image preview
                            Positioned.fill(
                              child: Image.file(
                                File(kf.imagePath),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Center(
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: Colors.grey[400],
                                        size: 40,
                                      ),
                                    ),
                              ),
                            ),

                            // Top bar with page badge and options icon
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Page ${kf.index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            // More options menu button for single page
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.more_vert,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () =>
                                    _showSinglePageOptions(kf, keyframes),
                              ),
                            ),

                            // Selection checkmark indicator
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.black.withValues(alpha: 0.4),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  isSelected
                                      ? Icons.check
                                      : Icons.circle_outlined,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            // Timestamp indicator bottom left
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${(kf.timestampMs / 1000).toStringAsFixed(0)}s',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          bottomNavigationBar: hasSelection
              ? SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2433) : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? const Color(0xFF2E384D)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${_selectedIds.length} page${_selectedIds.length > 1 ? 's' : ''} selected',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Delete'),
                          onPressed: _isProcessing
                              ? null
                              : () => _deleteSelected(keyframes),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
