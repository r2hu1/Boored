import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../data/capture_service.dart';
import '../data/opencv_service.dart';
import '../data/keyframe_policy.dart';
import '../data/mlkit_segmentation_engine.dart';
import '../domain/segmentation_engine.dart';
import 'widgets/board_overlay.dart';
import '../../notes/data/notes_repository.dart';

enum CapturePhase { idle, initializing, previewing, recording, paused, stopping, error }

class CaptureState {
  final CapturePhase phase;
  final int framesCaptured;
  final int keyframesSaved;
  final Duration elapsed;
  final String? noteId;
  final String? errorMessage;
  final int intervalSeconds;
  final String lastEventType;
  final bool removeLecturer;

  const CaptureState({
    this.phase = CapturePhase.idle,
    this.framesCaptured = 0,
    this.keyframesSaved = 0,
    this.elapsed = Duration.zero,
    this.noteId,
    this.errorMessage,
    this.intervalSeconds = 5,
    this.lastEventType = 'NONE',
    this.removeLecturer = true,
  });

  CaptureState copyWith({
    CapturePhase? phase,
    int? framesCaptured,
    int? keyframesSaved,
    Duration? elapsed,
    String? noteId,
    String? errorMessage,
    int? intervalSeconds,
    String? lastEventType,
    bool? removeLecturer,
  }) {
    return CaptureState(
      phase: phase ?? this.phase,
      framesCaptured: framesCaptured ?? this.framesCaptured,
      keyframesSaved: keyframesSaved ?? this.keyframesSaved,
      elapsed: elapsed ?? this.elapsed,
      noteId: noteId ?? this.noteId,
      errorMessage: errorMessage,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      lastEventType: lastEventType ?? this.lastEventType,
      removeLecturer: removeLecturer ?? this.removeLecturer,
    );
  }
}

class CaptureNotifier extends Notifier<CaptureState> {
  CaptureService? _service;
  late final OpenCVService _openCVService;
  late final KeyframePolicyManager _policyManager;
  SegmentationEngine? _segmentationEngine;
  Timer? _elapsedTimer;

  @override
  CaptureState build() {
    _openCVService = OpenCVService();
    _policyManager = KeyframePolicyManager(ref.watch(keyframesDaoProvider));

    ref.onDispose(() {
      _elapsedTimer?.cancel();
      _service?.dispose();
      _segmentationEngine?.dispose();
      WakelockPlus.disable();
    });
    return const CaptureState();
  }

  CaptureService? get service => _service;
  OpenCVService get openCVService => _openCVService;

  Future<CameraController> initCamera() async {
    state = state.copyWith(phase: CapturePhase.initializing);
    try {
      _service ??= CaptureService();
      final controller = await _service!.initCamera();
      state = state.copyWith(phase: CapturePhase.previewing);
      return controller;
    } catch (e) {
      state = state.copyWith(
        phase: CapturePhase.error,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> startRecording(
    String noteId, {
    List<BoardCorner>? corners,
    bool resume = false,
  }) async {
    _service ??= CaptureService();
    if (!resume) {
      _policyManager.reset();
    }

    state = state.copyWith(
      phase: CapturePhase.recording,
      noteId: noteId,
      framesCaptured: resume ? state.framesCaptured : 0,
      keyframesSaved: resume ? state.keyframesSaved : 0,
      elapsed: resume ? state.elapsed : Duration.zero,
    );

    await WakelockPlus.enable();

    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(
        elapsed: state.elapsed + const Duration(seconds: 1),
      );
    });

    await _service!.startCapture(
      noteId: noteId,
      interval: Duration(seconds: state.intervalSeconds),
      resume: resume,
      onFrameCaptured: (index, rawPath) async {
        String activePath = rawPath;

        // 1. Perspective warp to flatten the board
        if (corners != null && corners.length == 4) {
          final warpedPath = rawPath.replaceAll('.jpg', '_rectified.jpg');
          final success = await _openCVService.warpPerspective(
            srcPath: rawPath,
            dstPath: warpedPath,
            corners: corners,
          );
          if (success != null) {
            activePath = warpedPath;
          }
        }

        // 2. Whiteboard enhancement (contrast equalization + stroke sharpening)
        final enhancedPath = activePath.replaceAll('.jpg', '_enhanced.jpg');
        final enhanced = await _openCVService.enhanceWhiteboard(
          srcPath: activePath,
          dstPath: enhancedPath,
        );
        String finalFramePath = enhanced ?? activePath;

        // 2b. Real-time professor removal (if enabled)
        if (state.removeLecturer) {
          try {
            _segmentationEngine ??= MLKitSegmentationEngine();
            final mask = await _segmentationEngine!.processImage(finalFramePath);
            if (mask != null && mask.hasPerson) {
              // Use the previous clean frame as background reference
              final refFrame = _policyManager.previousFramePath;
              if (refFrame != null && refFrame != finalFramePath) {
                final deoccludedPath = finalFramePath.replaceAll('.jpg', '_deoccluded.jpg');
                final composited = await _openCVService.compositeUnoccluded(
                  currentPath: finalFramePath,
                  cleanBackgroundPath: refFrame,
                  dstPath: deoccludedPath,
                  maskConfidences: mask.confidences,
                  maskWidth: mask.width,
                  maskHeight: mask.height,
                );
                if (composited != null) {
                  finalFramePath = deoccludedPath;
                }
              }
            }
          } catch (_) {
            // Segmentation failure is non-fatal; keep the enhanced frame
          }
        }

        // 3. Change detection with previous frame
        String eventType = 'NONE';
        double diffRatio = 0.0;
        final prevFrame = _policyManager.previousFramePath;
        if (prevFrame != null) {
          final changeResult = await _openCVService.detectFrameChange(
            prevPath: prevFrame,
            currPath: finalFramePath,
          );
          eventType = changeResult.eventType;
          diffRatio = changeResult.diffRatio;
        }

        // 4. Keyframe policy evaluation
        final keyframe = await _policyManager.evaluateFrame(
          noteId: noteId,
          enhancedPath: finalFramePath,
          eventType: eventType,
          diffRatio: diffRatio,
          timestampMs: state.elapsed.inMilliseconds,
        );

        state = state.copyWith(
          framesCaptured: index + 1,
          keyframesSaved: keyframe != null
              ? state.keyframesSaved + 1
              : state.keyframesSaved,
          lastEventType: eventType,
        );
      },
      onError: (e) {
        state = state.copyWith(
          phase: CapturePhase.error,
          errorMessage: e.toString(),
        );
      },
    );
  }

  Future<void> pauseRecording() async {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    await _service?.stopCapture();
    await WakelockPlus.disable();
    state = state.copyWith(phase: CapturePhase.paused);
  }

  Future<void> finishRecording() async {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    await _service?.stopCapture();
    await WakelockPlus.disable();

    if (state.noteId != null) {
      try {
        final repo = ref.read(notesRepositoryProvider);
        await repo.updateStatus(state.noteId!, 'ready', durationMs: state.elapsed.inMilliseconds);
      } catch (_) {}
    }

    state = state.copyWith(phase: CapturePhase.previewing);
  }

  void setInterval(int seconds) {
    state = state.copyWith(intervalSeconds: seconds);
  }

  void toggleRemoveLecturer() {
    state = state.copyWith(removeLecturer: !state.removeLecturer);
  }

  Future<void> cleanup() async {
    _elapsedTimer?.cancel();
    await _service?.dispose();
    _service = null;
    await _segmentationEngine?.dispose();
    _segmentationEngine = null;
    await WakelockPlus.disable();
    state = const CaptureState();
  }
}

final captureNotifierProvider =
    NotifierProvider<CaptureNotifier, CaptureState>(
  () => CaptureNotifier(),
);
