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

          // Top floating action pill
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.45),
                      ),
                      onPressed: () => _handleBack(captureState),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (captureState.phase == CapturePhase.recording) ...[
                              _RecordingBadge(
                                elapsed: captureState.elapsed,
                                frames: captureState.framesCaptured,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                widget.noteTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (captureState.phase != CapturePhase.recording)
                      IconButton.filledTonal(
                        icon: _isAutoDetecting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.auto_fix_high, color: Colors.white, size: 20),
                        tooltip: 'Auto-detect board corners',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.45),
                        ),
                        onPressed: _isAutoDetecting ? null : _autoDetectCorners,
                      ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      icon: Icon(
                        captureState.removeLecturer
                            ? Icons.person_off_rounded
                            : Icons.person_rounded,
                        color: captureState.removeLecturer
                            ? const Color(0xFF60A5FA)
                            : Colors.white60,
                        size: 20,
                      ),
                      tooltip: captureState.removeLecturer
                          ? 'Remove Professor: Enabled'
                          : 'Remove Professor: Disabled',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.45),
                      ),
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
                  ],
                ),
              ),
            ),
          ),

          // Bottom modern control deck
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: false,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Interval selector pill
                      _IntervalSelector(
                        currentInterval: captureState.intervalSeconds,
                        enabled: captureState.phase != CapturePhase.recording,
                        onChanged: (v) => ref
                            .read(captureNotifierProvider.notifier)
                            .setInterval(v),
                      ),

                      // Record / Pause button (Modern M3 layout)
                      _RecordButton(
                        isRecording: captureState.phase == CapturePhase.recording,
                        isPaused: captureState.phase == CapturePhase.paused,
                        enabled: captureState.phase == CapturePhase.previewing ||
                            captureState.phase == CapturePhase.recording ||
                            captureState.phase == CapturePhase.paused,
                        onPressed: () => _toggleRecording(captureState),
                      ),

                      // Action pill or Stats counter
                      if (captureState.phase == CapturePhase.paused ||
                          captureState.phase == CapturePhase.recording ||
                          captureState.framesCaptured > 0)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: IconButton(
                            iconSize: 26,
                            icon: const Icon(Icons.check_rounded, color: Color(0xFF34D399)),
                            tooltip: 'Finish Recording',
                            onPressed: () => _finishRecording(),
                          ),
                        )
                      else
                        Container(
                          width: 72,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${captureState.keyframesSaved}',
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text(
                                'keyframes',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
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
          ),

          // Board cropping overlay sitting on top so corner handles receive all touches directly
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
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isRecording
                ? const Color(0xFFEF4444).withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.85),
            width: 4,
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          width: isRecording ? 32 : (isPaused ? 54 : 62),
          height: isRecording ? 32 : (isPaused ? 54 : 62),
          decoration: BoxDecoration(
            color: isRecording
                ? const Color(0xFFEF4444)
                : (isPaused ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
            borderRadius: BorderRadius.circular(isRecording ? 8 : 32),
            boxShadow: [
              BoxShadow(
                color: (isRecording ? const Color(0xFFEF4444) : Colors.black).withValues(alpha: 0.3),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: isPaused
                ? const Icon(Icons.play_arrow_rounded, color: Colors.black87, size: 32)
                : (isRecording
                    ? const Icon(Icons.pause_rounded, color: Colors.white, size: 22)
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.12 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: enabled ? 0.2 : 0.05),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              color: enabled ? Colors.white : Colors.white38,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              '${currentInterval}s',
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
