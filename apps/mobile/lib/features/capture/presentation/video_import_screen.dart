import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/video_import_service.dart';
import '../data/opencv_service.dart';
import '../data/keyframe_policy.dart';
import '../../../core/database/daos/keyframes_dao.dart';
import '../../../core/database/database_provider.dart';
import '../../notes/data/notes_repository.dart';

class VideoImportScreen extends ConsumerStatefulWidget {
  final String noteId;
  final String noteTitle;
  final String videoPath;

  const VideoImportScreen({
    super.key,
    required this.noteId,
    required this.noteTitle,
    required this.videoPath,
  });

  @override
  ConsumerState<VideoImportScreen> createState() => _VideoImportScreenState();
}

class _VideoImportScreenState extends ConsumerState<VideoImportScreen> {
  final _importService = VideoImportService();
  final _openCVService = OpenCVService();

  String _statusText = 'Preparing...';
  double _progress = 0.0;
  int _totalFrames = 0;
  int _processedFrames = 0;
  int _keyframesSaved = 0;
  bool _isDone = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startProcessing();
  }

  Future<void> _startProcessing() async {
    try {
      // Phase 1: Extract frames from video
      setState(() => _statusText = 'Extracting frames from video...');

      final extraction = await _importService.extractFrames(
        videoPath: widget.videoPath,
        noteId: widget.noteId,
        intervalMs: 5000,
      );

      final framePaths = extraction.framePaths;
      if (framePaths.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = 'No frames could be extracted from this video.';
        });
        return;
      }

      setState(() {
        _totalFrames = framePaths.length;
        _statusText = 'Processing frames...';
        _progress = 0.15;
      });

      // Phase 2: Run enhancement + change detection + keyframe policy
      final db = ref.read(databaseProvider);
      final keyframesDao = KeyframesDao(db);
      final policyManager = KeyframePolicyManager(keyframesDao);

      for (int i = 0; i < framePaths.length; i++) {
        if (!mounted) return;

        final rawPath = framePaths[i];

        // 1. Whiteboard enhancement
        final enhancedPath = rawPath.replaceAll('.jpg', '_enhanced.jpg');
        final enhanced = await _openCVService.enhanceWhiteboard(
          srcPath: rawPath,
          dstPath: enhancedPath,
        );
        final finalFramePath = enhanced ?? rawPath;

        // 2. Change detection
        String eventType = 'NONE';
        double diffRatio = 0.0;
        final prevFrame = policyManager.previousFramePath;
        if (prevFrame != null) {
          final changeResult = await _openCVService.detectFrameChange(
            prevPath: prevFrame,
            currPath: finalFramePath,
          );
          eventType = changeResult.eventType;
          diffRatio = changeResult.diffRatio;
        }

        // 3. Keyframe policy
        final timestampMs = i * 5000;
        final keyframe = await policyManager.evaluateFrame(
          noteId: widget.noteId,
          enhancedPath: finalFramePath,
          eventType: eventType,
          diffRatio: diffRatio,
          timestampMs: timestampMs,
        );

        setState(() {
          _processedFrames = i + 1;
          _progress = 0.15 + (0.85 * _processedFrames / _totalFrames);
          _statusText = 'Processing frame ${i + 1} of $_totalFrames...';
          if (keyframe != null) _keyframesSaved++;
        });
      }

      // Mark note as ready
      final repo = ref.read(notesRepositoryProvider);
      await repo.updateStatus(
        widget.noteId,
        'ready',
        durationMs: extraction.durationMs,
      );

      if (mounted) {
        setState(() {
          _isDone = true;
          _progress = 1.0;
          _statusText = 'Done! $_keyframesSaved keyframes saved.';
        });

        // Auto-navigate after a short pause
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          context.go('/notes/${widget.noteId}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.noteTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_hasError) ...[
                Icon(
                  Icons.error_outline_rounded,
                  size: 72,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 20),
                Text(
                  'Import Failed',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ] else if (_isDone) ...[
                Icon(
                  Icons.check_circle_rounded,
                  size: 72,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(height: 20),
                Text(
                  'Import Complete',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_keyframesSaved keyframes saved from $_totalFrames frames',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                // Animated processing icon
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: _progress > 0.05 ? _progress : null,
                          strokeWidth: 4,
                          color: theme.colorScheme.primary,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      Icon(
                        Icons.video_library_rounded,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _statusText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_totalFrames > 0) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatChip(
                        icon: Icons.photo_outlined,
                        label: '$_processedFrames / $_totalFrames',
                        caption: 'frames',
                      ),
                      const SizedBox(width: 24),
                      _StatChip(
                        icon: Icons.bookmark_outlined,
                        label: '$_keyframesSaved',
                        caption: 'keyframes',
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String caption;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
