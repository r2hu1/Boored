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
  double _playbackSpeed = 1.0;

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

  Future<void> _runFinalPass() async {
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

      await finalizer.finalizeNote(widget.noteId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Processing & PDF generation complete!')),
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
                  if (val == 'rename') _showRenameDialog(note);
                  if (val == 'open_pdf') _openPdfExternally();
                  if (val == 'download_pdf') _downloadPdfToDownloads(note);
                  if (val == 'delete') _confirmDelete(note);
                },
                itemBuilder: (ctx) => [
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

    return Column(
      children: [
        // Frame Viewport
        Expanded(
          child: Container(
            color: isDark ? const Color(0xFF0B0F17) : const Color(0xFF0F172A),
            child: Center(
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

        // Event banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                width: 1,
              ),
              bottom: BorderSide(
                color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Frame ${_currentKeyframeIndex + 1} of ${uniqueKeyframes.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: currentKeyframe.eventType == 'ERASE'
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                      : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  currentKeyframe.eventType,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: currentKeyframe.eventType == 'ERASE'
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Controls bar
        Container(
          color: isDark ? const Color(0xFF111622) : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: _currentKeyframeIndex.toDouble(),
                  min: 0,
                  max: (uniqueKeyframes.length > 1 ? uniqueKeyframes.length - 1 : 1).toDouble(),
                  divisions: uniqueKeyframes.length > 1 ? uniqueKeyframes.length - 1 : null,
                  onChanged: uniqueKeyframes.length > 1
                      ? (val) {
                          setState(() => _currentKeyframeIndex = val.toInt());
                        }
                      : null,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 22,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: _currentKeyframeIndex > 0
                        ? () => setState(() => _currentKeyframeIndex--)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    iconSize: 36,
                    icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                    onPressed: uniqueKeyframes.length > 1
                        ? () {
                            setState(() => _isPlaying = !_isPlaying);
                            if (_isPlaying) _startPlaybackLoop(uniqueKeyframes);
                          }
                        : null,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    iconSize: 22,
                    icon: const Icon(Icons.skip_next),
                    onPressed: _currentKeyframeIndex < uniqueKeyframes.length - 1
                        ? () => setState(() => _currentKeyframeIndex++)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      setState(() {
                        if (_playbackSpeed == 1.0) {
                          _playbackSpeed = 2.0;
                        } else if (_playbackSpeed == 2.0) {
                          _playbackSpeed = 0.5;
                        } else {
                          _playbackSpeed = 1.0;
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E384D) : const Color(0xFFCBD5E1),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_playbackSpeed}x',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ),
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

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: keyframes.length,
      itemBuilder: (context, index) {
        final kf = keyframes[index];
        final hasText = kf.extractedText != null && kf.extractedText!.trim().isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B26) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              setState(() {
                _currentKeyframeIndex = index;
                _tabController.animateTo(0);
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    child: File(kf.imagePath).existsSync()
                        ? Image.file(File(kf.imagePath), fit: BoxFit.cover)
                        : Icon(
                            Icons.broken_image,
                            size: 24,
                            color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                          ),
                  ),
                ),
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
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: kf.extractedText!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Text copied')),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.copy,
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
        );
      },
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
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2430) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Regenerate',
                  onPressed: widget.onRegenerate,
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 20),
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
