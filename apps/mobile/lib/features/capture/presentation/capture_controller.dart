import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../data/capture_service.dart';
import '../data/opencv_service.dart';
import 'widgets/board_overlay.dart';
import '../../notes/data/notes_repository.dart';

enum CapturePhase { idle, initializing, previewing, recording, paused, stopping, error }

class CaptureState {
  final CapturePhase phase;
  final int framesCaptured;
  final Duration elapsed;
  final String? noteId;
  final String? errorMessage;
  final int intervalSeconds;

  const CaptureState({
    this.phase = CapturePhase.idle,
    this.framesCaptured = 0,
    this.elapsed = Duration.zero,
    this.noteId,
    this.errorMessage,
    this.intervalSeconds = 5,
  });

  CaptureState copyWith({
    CapturePhase? phase,
    int? framesCaptured,
    Duration? elapsed,
    String? noteId,
    String? errorMessage,
    int? intervalSeconds,
  }) {
    return CaptureState(
      phase: phase ?? this.phase,
      framesCaptured: framesCaptured ?? this.framesCaptured,
      elapsed: elapsed ?? this.elapsed,
      noteId: noteId ?? this.noteId,
      errorMessage: errorMessage,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
    );
  }
}

class CaptureNotifier extends Notifier<CaptureState> {
  CaptureService? _service;
  late final OpenCVService _openCVService;
  Timer? _elapsedTimer;

  @override
  CaptureState build() {
    _openCVService = OpenCVService();
    ref.onDispose(() {
      _elapsedTimer?.cancel();
      _service?.dispose();
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
  }) async {
    _service ??= CaptureService();
    state = state.copyWith(
      phase: CapturePhase.recording,
      noteId: noteId,
      framesCaptured: state.framesCaptured,
      elapsed: state.elapsed,
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
      onFrameCaptured: (index, rawPath) async {
        if (corners != null && corners.length == 4) {
          final warpedPath = rawPath.replaceAll('.jpg', '_rectified.jpg');
          await _openCVService.warpPerspective(
            srcPath: rawPath,
            dstPath: warpedPath,
            corners: corners,
          );
        }
        state = state.copyWith(framesCaptured: index + 1);
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

  Future<void> stopRecording() async {
    state = state.copyWith(phase: CapturePhase.stopping);
    _elapsedTimer?.cancel();
    _elapsedTimer = null;

    await _service?.stopCapture();
    await WakelockPlus.disable();

    if (state.noteId != null) {
      try {
        final repo = ref.read(notesRepositoryProvider);
        await repo.updateTitle(state.noteId!, state.noteId!);
      } catch (_) {}
    }

    state = state.copyWith(phase: CapturePhase.previewing);
  }

  void setInterval(int seconds) {
    state = state.copyWith(intervalSeconds: seconds);
  }

  Future<void> cleanup() async {
    _elapsedTimer?.cancel();
    await _service?.dispose();
    _service = null;
    await WakelockPlus.disable();
    state = const CaptureState();
  }
}

final captureNotifierProvider =
    NotifierProvider.autoDispose<CaptureNotifier, CaptureState>(
  () => CaptureNotifier(),
);
