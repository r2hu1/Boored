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

  // Timeline player state
  int _currentKeyframeIndex = 0;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;

  // PDF state
  PdfControllerPinch? _pdfController;
  bool _isLoadingPdf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        _loadPdf();
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

        return Scaffold(
          appBar: AppBar(
            title: Text(note.title),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.timeline), text: 'Timeline'),
                Tab(icon: Icon(Icons.grid_view), text: 'Pages'),
                Tab(icon: Icon(Icons.picture_as_pdf_outlined), text: 'PDF'),
              ],
            ),
            actions: [
              if (_isFinalizing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  tooltip: 'Run Final Pass (Deocclude & OCR)',
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
                  if (val == 'delete') _confirmDelete(note);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: keyframesAsync.when(
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
                  _buildPdfTab(),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTimelineTab(List<Keyframe> keyframes) {
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
            color: Colors.black,
            child: Center(
              child: File(currentKeyframe.imagePath).existsSync()
                  ? Image.file(
                      File(currentKeyframe.imagePath),
                      key: ValueKey(currentKeyframe.id),
                      fit: BoxFit.contain,
                    )
                  : const Icon(Icons.broken_image, size: 64, color: Colors.white54),
            ),
          ),
        ),

        // Event banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Keyframe ${_currentKeyframeIndex + 1} of ${uniqueKeyframes.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: currentKeyframe.eventType == 'ERASE'
                      ? Colors.orange.shade100
                      : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  currentKeyframe.eventType,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: currentKeyframe.eventType == 'ERASE'
                        ? Colors.orange.shade900
                        : Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Slider(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: _currentKeyframeIndex > 0
                        ? () => setState(() => _currentKeyframeIndex--)
                        : null,
                  ),
                  IconButton(
                    iconSize: 42,
                    icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                    onPressed: uniqueKeyframes.length > 1
                        ? () {
                            setState(() => _isPlaying = !_isPlaying);
                            if (_isPlaying) _startPlaybackLoop(uniqueKeyframes);
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: _currentKeyframeIndex < uniqueKeyframes.length - 1
                        ? () => setState(() => _currentKeyframeIndex++)
                        : null,
                  ),
                  TextButton(
                    onPressed: () {
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
                    child: Text('${_playbackSpeed}x'),
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
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: keyframes.length,
      itemBuilder: (context, index) {
        final kf = keyframes[index];
        return Card(
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
                  child: File(kf.imagePath).existsSync()
                      ? Image.file(File(kf.imagePath), fit: BoxFit.cover)
                      : Container(color: Colors.grey.shade300),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Page ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (kf.extractedText != null && kf.extractedText!.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: 'Copy extracted text',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: kf.extractedText!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Text copied to clipboard!')),
                            );
                          },
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

  Widget _buildPdfTab() {
    if (_isLoadingPdf) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pdfController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('PDF has not been generated yet.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Document PDF'),
              onPressed: _runFinalPass,
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        PdfViewPinch(
          controller: _pdfController!,
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            icon: const Icon(Icons.share),
            label: const Text('Share PDF'),
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
        ),
      ],
    );
  }

  Future<void> _showRenameDialog(Note note) async {
    final controller = TextEditingController(text: note.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Rename Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.of(dialogCtx).pop(text);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();

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
