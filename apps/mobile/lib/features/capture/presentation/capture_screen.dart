import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'capture_controller.dart';
import 'widgets/board_overlay.dart';
import '../data/opencv_service.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  final String noteId;
  final String noteTitle;

  const CaptureScreen({
    super.key,
    required this.noteId,
    required this.noteTitle,
  });

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _permissionDenied = false;
  List<BoardCorner> _corners = const [
    BoardCorner(0.1, 0.1),
    BoardCorner(0.9, 0.1),
    BoardCorner(0.9, 0.8),
    BoardCorner(0.1, 0.8),
  ];
  bool _showOverlay = true;

  final OpenCVService _openCVService = OpenCVService();
  bool _isAutoDetecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissionAndInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Camera resources freed when app goes to background
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _requestPermissionAndInit() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initCamera();
    } else {
      setState(() => _permissionDenied = true);
    }
  }

  Future<void> _initCamera() async {
    try {
      final controller =
          await ref.read(captureNotifierProvider.notifier).initCamera();
      if (mounted) {
        setState(() => _cameraController = controller);
      }
    } catch (e) {
      // Error state handled by captureNotifierProvider
    }
  }

  Future<void> _autoDetectCorners() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isAutoDetecting) {
      return;
    }

    setState(() => _isAutoDetecting = true);
    try {
      final shot = await _cameraController!.takePicture();
      final detected = await _openCVService.detectBoardCorners(shot.path);
      if (mounted) {
        setState(() {
          _corners = detected;
          _showOverlay = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Board corners detected! Adjust handles if needed.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not detect clear board corners. Manual adjust available.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAutoDetecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final captureState = ref.watch(captureNotifierProvider);

    if (_permissionDenied) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.noteTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.no_photography_outlined,
                    size: 64, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                const Text(
                  'Camera permission is required to capture whiteboards',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (captureState.phase == CapturePhase.error) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.noteTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(captureState.errorMessage ?? 'Camera error',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _initCamera,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fullscreen camera preview with BoxFit.cover
          if (_cameraController != null &&
              _cameraController!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ??
                      MediaQuery.of(context).size.width,
                  height: _cameraController!.value.previewSize?.width ??
                      MediaQuery.of(context).size.height,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Board cropping overlay sitting directly on viewport coordinates
          if (_showOverlay)
            Positioned.fill(
              child: BoardOverlay(
                corners: _corners,
                editable: captureState.phase != CapturePhase.recording,
                onCornersChanged: (corners) {
                  setState(() => _corners = corners);
                },
              ),
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => _handleBack(captureState),
                    ),
                    Expanded(
                      child: Text(
                        widget.noteTitle,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (captureState.phase != CapturePhase.recording)
                      IconButton(
                        icon: _isAutoDetecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.auto_fix_high, color: Colors.white),
                        tooltip: 'Auto-detect board corners',
                        onPressed: _isAutoDetecting ? null : _autoDetectCorners,
                      ),
                    IconButton(
                      icon: Icon(
                        captureState.removeLecturer
                            ? Icons.person_off_rounded
                            : Icons.person_rounded,
                        color: captureState.removeLecturer
                            ? Colors.white
                            : Colors.white54,
                      ),
                      tooltip: captureState.removeLecturer
                          ? 'Remove Professor: Enabled'
                          : 'Remove Professor: Disabled',
                      onPressed: () {
                        ref.read(captureNotifierProvider.notifier).toggleRemoveLecturer();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              !captureState.removeLecturer
                                  ? 'Professor removal enabled'
                                  : 'Professor removal disabled',
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        _showOverlay ? Icons.crop_free : Icons.crop,
                        color: Colors.white,
                      ),
                      tooltip: _showOverlay ? 'Hide Outline' : 'Show Outline',
                      onPressed: () => setState(() => _showOverlay = !_showOverlay),
                    ),
                    if (captureState.phase == CapturePhase.recording)
                      _RecordingBadge(
                        elapsed: captureState.elapsed,
                        frames: captureState.framesCaptured,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Interval selector
                    _IntervalSelector(
                      currentInterval: captureState.intervalSeconds,
                      enabled: captureState.phase != CapturePhase.recording,
                      onChanged: (v) => ref
                          .read(captureNotifierProvider.notifier)
                          .setInterval(v),
                    ),
                    // Record / Pause button
                    _RecordButton(
                      isRecording:
                          captureState.phase == CapturePhase.recording,
                      isPaused: captureState.phase == CapturePhase.paused,
                      enabled: captureState.phase == CapturePhase.previewing ||
                          captureState.phase == CapturePhase.recording ||
                          captureState.phase == CapturePhase.paused,
                      onPressed: () => _toggleRecording(captureState),
                    ),
                    // Finish button when paused or recording
                    if (captureState.phase == CapturePhase.paused ||
                        captureState.phase == CapturePhase.recording ||
                        captureState.framesCaptured > 0)
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(Icons.check, color: Colors.white, size: 28),
                        tooltip: 'Finish Recording',
                        onPressed: () => _finishRecording(),
                      )
                    else
                      // Frame & Keyframe counters
                      SizedBox(
                        width: 80,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${captureState.keyframesSaved} keyframes',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              '${captureState.framesCaptured} frames',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleRecording(CaptureState captureState) {
    final notifier = ref.read(captureNotifierProvider.notifier);
    if (captureState.phase == CapturePhase.recording) {
      notifier.pauseRecording();
    } else if (captureState.phase == CapturePhase.paused) {
      notifier.startRecording(widget.noteId, corners: _corners, resume: true);
    } else if (captureState.phase == CapturePhase.previewing) {
      notifier.startRecording(widget.noteId, corners: _corners, resume: false);
    }
  }

  Future<void> _finishRecording() async {
    await ref.read(captureNotifierProvider.notifier).finishRecording();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleBack(CaptureState captureState) async {
    if (captureState.phase == CapturePhase.recording) {
      await ref.read(captureNotifierProvider.notifier).pauseRecording();
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _RecordingBadge extends StatelessWidget {
  final Duration elapsed;
  final int frames;

  const _RecordingBadge({required this.elapsed, required this.frames});

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = elapsed.inHours;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final bool isRecording;
  final bool isPaused;
  final bool enabled;
  final VoidCallback onPressed;

  const _RecordButton({
    required this.isRecording,
    this.isPaused = false,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        padding: const EdgeInsets.all(4),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isRecording ? 28 : (isPaused ? 48 : 56),
            height: isRecording ? 28 : (isPaused ? 48 : 56),
            decoration: BoxDecoration(
              color: isRecording ? Colors.red : (isPaused ? Colors.amber : Colors.red.shade400),
              shape: isRecording ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isRecording ? BorderRadius.circular(6) : null,
            ),
            child: isPaused
                ? const Icon(Icons.play_arrow, color: Colors.black, size: 30)
                : (isRecording
                    ? const Icon(Icons.pause, color: Colors.white, size: 20)
                    : null),
          ),
        ),
      ),
    );
  }
}

class _IntervalSelector extends StatelessWidget {
  final int currentInterval;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _IntervalSelector({
    required this.currentInterval,
    required this.enabled,
    required this.onChanged,
  });

  static const _options = [3, 5, 10, 15, 30];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      enabled: enabled,
      onSelected: onChanged,
      initialValue: currentInterval,
      itemBuilder: (_) => _options
          .map((s) => PopupMenuItem(value: s, child: Text('${s}s interval')))
          .toList(),
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined,
                color: enabled ? Colors.white : Colors.white38, size: 20),
            const SizedBox(height: 2),
            Text(
              '${currentInterval}s',
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
