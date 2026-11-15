import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/keyframes_dao.dart';
import '../../../core/database/daos/notes_dao.dart';
import '../../../core/database/database_provider.dart';
import '../../capture/data/keyframe_policy.dart';
import '../../capture/data/lecturer_removal_processor.dart';
import '../../capture/data/mlkit_recognition_engine.dart';
import '../../capture/data/mlkit_segmentation_engine.dart';
import '../../capture/data/opencv_service.dart';
import '../../capture/data/session_finalizer.dart';
import 'notes_controller.dart';

final _noteProvider = StreamProvider.autoDispose.family<Note?, String>((ref, noteId) {
  final db = ref.watch(databaseProvider);
  return NotesDao(db).watchNote(noteId);
});

final _keyframesProvider =
    StreamProvider.autoDispose.family<List<Keyframe>, String>((ref, noteId) {
  final dao = ref.watch(keyframesDaoProvider);
  return dao.watchKeyframesForNote(noteId);
});

class NoteDetailScreen extends ConsumerStatefulWidget {
  final String noteId;

  const NoteDetailScreen({super.key, required this.noteId});

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isFinalizing = false;
  int _pdfReloadTrigger = 0;

  // Timeline player state
  int _currentKeyframeIndex = 0;
  bool _isPlaying = false;
  final double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _runFinalPass({bool removeLecturer = true}) async {
    setState(() => _isFinalizing = true);
    try {
      final db = ref.read(databaseProvider);
      final finalizer = SessionFinalizer(
        notesDao: NotesDao(db),
        keyframesDao: KeyframesDao(db),
        recognitionEngine: MLKitRecognitionEngine(),
        lecturerRemovalProcessor: LecturerRemovalProcessor(
          segmenter: MLKitSegmentationEngine(),
          openCVService: OpenCVService(),
        ),
      );

      await finalizer.finalizeNote(widget.noteId, removeLecturer: removeLecturer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              removeLecturer
                  ? 'Professor removal & finalization complete!'
                  : 'Processing complete!',
            ),
          ),
        );
        setState(() => _pdfReloadTrigger++);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error finalizing note: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFinalizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(_noteProvider(widget.noteId));
    final keyframesAsync = ref.watch(_keyframesProvider(widget.noteId));

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

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            title: Text(
              note.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorWeight: 2,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timeline, size: 16),
                          SizedBox(width: 6),
                          Text('Timeline'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.grid_view, size: 16),
                          SizedBox(width: 6),
                          Text('Pages'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('PDF'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (_isFinalizing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Process / Generate PDF',
                  onPressed: _runFinalPass,
                ),
              IconButton(
                icon: const Icon(Icons.videocam_outlined),
                tooltip: 'Capture / Resume',
                onPressed: () {
                  context.push(
                    '/capture/${note.id}?title=${Uri.encodeComponent(note.title)}',
                  );
                },
              ),
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'remove_professor') _runFinalPass(removeLecturer: true);
                  if (val == 'rename') _showRenameDialog(note);
                  if (val == 'open_pdf') _openPdfExternally();
                  if (val == 'download_pdf') _downloadPdfToDownloads(note);
                  if (val == 'delete') _confirmDelete(note);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'remove_professor',
                    child: Row(
                      children: [
                        Icon(Icons.person_off_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Remove professor'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'open_pdf',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new, size: 18),
                        SizedBox(width: 10),
                        Text('Open externally'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'download_pdf',
                    child: Row(
                      children: [
                        Icon(Icons.download_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Save to Downloads'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            bottom: true,
            top: false,
            child: keyframesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading keyframes: $e')),
              data: (keyframes) {
                if (keyframes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam_off_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('No keyframes recorded for this session yet.'),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          icon: const Icon(Icons.videocam),
                          label: const Text('Start Capture'),
                          onPressed: () {
                            context.push(
                              '/capture/${note.id}?title=${Uri.encodeComponent(note.title)}',
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTimelineTab(keyframes),
                    _buildPagesGridTab(keyframes),
                    _PdfTab(
                      key: ValueKey('${widget.noteId}_$_pdfReloadTrigger'),
                      noteId: widget.noteId,
                      onRegenerate: _runFinalPass,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineTab(List<Keyframe> keyframes) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Deduplicate keyframes by unique imagePath while preserving sequence order
    final uniqueKeyframes = <Keyframe>[];
    final seenPaths = <String>{};
    for (final kf in keyframes) {
      if (seenPaths.add(kf.imagePath)) {
        uniqueKeyframes.add(kf);
      }
    }

    if (_currentKeyframeIndex >= uniqueKeyframes.length) {
      _currentKeyframeIndex = uniqueKeyframes.isNotEmpty ? uniqueKeyframes.length - 1 : 0;
    }
    final currentKeyframe = uniqueKeyframes[_currentKeyframeIndex];
    final totalFrames = uniqueKeyframes.length;

    return Column(
      children: [
        // Frame Viewport with floating overlay badge
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: isDark ? const Color(0xFF070A0F) : const Color(0xFF0F172A),
                child: Center(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 3.5,
                    child: File(currentKeyframe.imagePath).existsSync()
                        ? Image.file(
                            File(currentKeyframe.imagePath),
                            key: ValueKey(currentKeyframe.id),
                            fit: BoxFit.contain,
                          )
                        : const Icon(Icons.broken_image, size: 48, color: Colors.white24),
                  ),
                ),
              ),

              // Floating minimal top badge
              Positioned(
                top: 12,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: currentKeyframe.eventType == 'ERASE'
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_currentKeyframeIndex + 1} / $totalFrames',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Material 3 Control Deck
        Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.6),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // M3 Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: theme.colorScheme.primary,
                  inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
                  thumbColor: theme.colorScheme.primary,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: _currentKeyframeIndex.toDouble(),
                  min: 0,
                  max: (totalFrames > 1 ? totalFrames - 1 : 1).toDouble(),
                  divisions: totalFrames > 1 ? totalFrames - 1 : null,
                  onChanged: totalFrames > 1
                      ? (val) {
                          setState(() => _currentKeyframeIndex = val.toInt());
                        }
                      : null,
                ),
              ),

              const SizedBox(height: 4),

              // M3 Transport controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Step back
                  IconButton.filledTonal(
                    iconSize: 20,
                    icon: const Icon(Icons.skip_previous_rounded),
                    tooltip: 'Previous frame',
                    onPressed: _currentKeyframeIndex > 0
                        ? () => setState(() => _currentKeyframeIndex--)
                        : null,
                  ),

                  const SizedBox(width: 16),

                  // M3 Filled Play/Pause Button
                  IconButton.filled(
                    iconSize: 32,
                    padding: const EdgeInsets.all(12),
                    icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    tooltip: _isPlaying ? 'Pause' : 'Play',
                    onPressed: totalFrames > 1
                        ? () {
                            setState(() => _isPlaying = !_isPlaying);
                            if (_isPlaying) _startPlaybackLoop(uniqueKeyframes);
                          }
                        : null,
                  ),

                  const SizedBox(width: 16),

                  // Step forward
                  IconButton.filledTonal(
                    iconSize: 20,
                    icon: const Icon(Icons.skip_next_rounded),
                    tooltip: 'Next frame',
                    onPressed: _currentKeyframeIndex < totalFrames - 1
                        ? () => setState(() => _currentKeyframeIndex++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _startPlaybackLoop(List<Keyframe> keyframes) async {
    while (_isPlaying && mounted) {
      await Future.delayed(Duration(milliseconds: (1500 / _playbackSpeed).toInt()));
      if (!_isPlaying || !mounted) break;

      setState(() {
        if (_currentKeyframeIndex < keyframes.length - 1) {
          _currentKeyframeIndex++;
        } else {
          _currentKeyframeIndex = 0;
          _isPlaying = false;
        }
      });
    }
  }

  Widget _buildPagesGridTab(List<Keyframe> keyframes) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Split items into 2 columns for a clean staggered masonry layout
    final leftColumn = <int>[];
    final rightColumn = <int>[];
    for (int i = 0; i < keyframes.length; i++) {
      if (i.isEven) {
        leftColumn.add(i);
      } else {
        rightColumn.add(i);
      }
    }

    Widget buildTile(int index) {
      final kf = keyframes[index];
      final hasText = kf.extractedText != null && kf.extractedText!.trim().isNotEmpty;
      final file = File(kf.imagePath);
      final exists = file.existsSync();

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              setState(() {
                _currentKeyframeIndex = index;
                _tabController.animateTo(0);
              });
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Natural aspect image
                  if (exists)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      child: Image.file(
                        file,
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.topCenter,
                      ),
                    )
                  else
                    Container(
                      height: 120,
                      color: isDark ? const Color(0xFF161B26) : const Color(0xFFF1F5F9),
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 28,
                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      ),
                    ),

                  // Footer bar with page label and copy text action
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Page ${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        if (hasText)
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: kf.extractedText!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Text copied to clipboard'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: leftColumn.map(buildTile).toList(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: rightColumn.map(buildTile).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPdfExternally() async {
    final appDir = await getApplicationDocumentsDirectory();
    final pdfPath = p.join(appDir.path, 'captures', widget.noteId, 'document.pdf');
    final file = File(pdfPath);
    if (!file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please generate PDF first')),
        );
      }
      return;
    }
    await OpenCVService().openPdf(pdfPath);
  }

  Future<void> _downloadPdfToDownloads(Note note) async {
    final appDir = await getApplicationDocumentsDirectory();
    final pdfPath = p.join(appDir.path, 'captures', widget.noteId, 'document.pdf');
    final file = File(pdfPath);
    if (!file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please generate PDF first')),
        );
      }
      return;
    }

    try {
      final downloadDir = Directory('/sdcard/Download');
      final sanitizedTitle = note.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final targetFile = File('${downloadDir.path}/${sanitizedTitle}_document.pdf');
      await file.copy(targetFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to Downloads: ${targetFile.path}'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => OpenCVService().openPdf(targetFile.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save to Downloads: $e')),
        );
      }
    }
  }

  Future<void> _showRenameDialog(Note note) async {
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => _RenameNoteDialog(initialTitle: note.title),
    );

    if (!mounted || newTitle == null || newTitle == note.title) return;
    await ref.read(notesNotifierProvider.notifier).updateNoteTitle(widget.noteId, newTitle);
  }

  Future<void> _confirmDelete(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final errorColor = Theme.of(dialogCtx).colorScheme.error;
        return AlertDialog(
          title: const Text('Delete Note?'),
          content: Text('Delete "${note.title}"? You can undo this from the notes list.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: errorColor,
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    final noteId = widget.noteId;
    final notifier = ref.read(notesNotifierProvider.notifier);
    context.pop();
    notifier.deleteNote(noteId);
  }
}

class _RenameNoteDialog extends StatefulWidget {
  final String initialTitle;

  const _RenameNoteDialog({required this.initialTitle});

  @override
  State<_RenameNoteDialog> createState() => _RenameNoteDialogState();
}

class _RenameNoteDialogState extends State<_RenameNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Note'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Title'),
        onSubmitted: (val) {
          final text = val.trim();
          if (text.isNotEmpty) Navigator.of(context).pop(text);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) Navigator.of(context).pop(text);
          },
          child: const Text('Rename'),
        ),
      ],
    );
  }
}

class _PdfTab extends StatefulWidget {
  final String noteId;
  final VoidCallback onRegenerate;

  const _PdfTab({
    super.key,
    required this.noteId,
    required this.onRegenerate,
  });

  @override
  State<_PdfTab> createState() => _PdfTabState();
}

class _PdfTabState extends State<_PdfTab>
    with AutomaticKeepAliveClientMixin {
  PdfControllerPinch? _pdfController;
  bool _isLoadingPdf = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    setState(() => _isLoadingPdf = true);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final pdfPath = p.join(appDir.path, 'captures', widget.noteId, 'document.pdf');
      final file = File(pdfPath);
      if (file.existsSync()) {
        final ctrl = PdfControllerPinch(
          document: PdfDocument.openFile(pdfPath),
        );
        if (mounted) {
          setState(() {
            _pdfController?.dispose();
            _pdfController = ctrl;
            _isLoadingPdf = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingPdf = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPdf = false);
    }
  }

  Future<void> _openPdfExternally() async {
    final appDir = await getApplicationDocumentsDirectory();
    final pdfPath = p.join(appDir.path, 'captures', widget.noteId, 'document.pdf');
    final file = File(pdfPath);
    if (!file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please generate PDF first')),
        );
      }
      return;
    }
    await OpenCVService().openPdf(pdfPath);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoadingPdf) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pdfController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 48,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            Text(
              'PDF not generated yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Generate Document PDF'),
              onPressed: widget.onRegenerate,
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Container(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          child: PdfViewPinch(
            controller: _pdfController!,
            builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(),
              documentLoaderBuilder: (_) => const Center(
                child: CircularProgressIndicator(),
              ),
              pageLoaderBuilder: (_) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorBuilder: (_, error) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 36, color: Color(0xFFEF4444)),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to render PDF: $error',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _openPdfExternally,
                      child: const Text('Open in External Viewer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'regenerate_pdf_btn',
                tooltip: 'Regenerate PDF',
                onPressed: widget.onRegenerate,
                child: const Icon(Icons.refresh),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'share_pdf_btn',
                tooltip: 'Share PDF',
                onPressed: () async {
                  final appDir = await getApplicationDocumentsDirectory();
                  final pdfPath = p.join(appDir.path, 'captures', widget.noteId, 'document.pdf');
                  if (File(pdfPath).existsSync()) {
                    await SharePlus.instance.share(
                      ShareParams(
                        files: [XFile(pdfPath)],
                        title: 'Whiteboard PDF',
                      ),
                    );
                  }
                },
                child: const Icon(Icons.share_outlined),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
