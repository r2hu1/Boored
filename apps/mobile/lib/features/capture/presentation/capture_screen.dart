import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'capture_controller.dart';
import 'widgets/board_overlay.dart';

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
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview
            if (_cameraController != null &&
                _cameraController!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _cameraController!.value.aspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_cameraController!),
                      if (_showOverlay)
                        BoardOverlay(
                          corners: _corners,
                          editable: captureState.phase != CapturePhase.recording,
                          onCornersChanged: (corners) {
                            setState(() => _corners = corners);
                          },
                        ),
                    ],
                  ),
                ),
              )
            else
              const Center(child: CircularProgressIndicator(color: Colors.white)),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
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

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
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
                    // Record / Stop button
                    _RecordButton(
                      isRecording:
                          captureState.phase == CapturePhase.recording,
                      enabled: captureState.phase == CapturePhase.previewing ||
                          captureState.phase == CapturePhase.recording,
                      onPressed: () => _toggleRecording(captureState),
                    ),
                    // Frame count
                    SizedBox(
                      width: 72,
                      child: Text(
                        '${captureState.framesCaptured} frames',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleRecording(CaptureState captureState) {
    final notifier = ref.read(captureNotifierProvider.notifier);
    if (captureState.phase == CapturePhase.recording) {
      notifier.stopRecording();
    } else if (captureState.phase == CapturePhase.previewing) {
      notifier.startRecording(widget.noteId);
    }
  }

  Future<void> _handleBack(CaptureState captureState) async {
    if (captureState.phase == CapturePhase.recording) {
      final stop = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Stop Recording?'),
          content: const Text(
              'Going back will stop the current capture session.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continue Recording'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Stop & Go Back'),
            ),
          ],
        ),
      );
      if (stop != true) return;
      await ref.read(captureNotifierProvider.notifier).stopRecording();
    }
    if (mounted) Navigator.of(context).pop();
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
  final bool enabled;
  final VoidCallback onPressed;

  const _RecordButton({
    required this.isRecording,
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isRecording ? Colors.red : Colors.red.shade300,
            shape: isRecording ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: isRecording ? BorderRadius.circular(8) : null,
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
