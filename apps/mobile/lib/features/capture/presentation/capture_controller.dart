import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../data/capture_service.dart';
import '../../notes/presentation/notes_controller.dart';

enum CapturePhase { idle, initializing, previewing, recording, stopping, error }

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
  late final CaptureService _service;
  Timer? _elapsedTimer;

  @override
  CaptureState build() {
    _service = CaptureService();
    ref.onDispose(() {
      _elapsedTimer?.cancel();
      _service.dispose();
      WakelockPlus.disable();
    });
    return const CaptureState();
  }

  CaptureService get service => _service;

  Future<CameraController> initCamera() async {
    state = state.copyWith(phase: CapturePhase.initializing);
    try {
      final controller = await _service.initCamera();
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

  Future<void> startRecording(String noteId) async {
    state = state.copyWith(
      phase: CapturePhase.recording,
      noteId: noteId,
      framesCaptured: 0,
      elapsed: Duration.zero,
    );

    await WakelockPlus.enable();

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(
        elapsed: state.elapsed + const Duration(seconds: 1),
      );
    });

    await _service.startCapture(
      noteId: noteId,
      interval: Duration(seconds: state.intervalSeconds),
      onFrameCaptured: (index, path) {
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

  Future<void> stopRecording() async {
    state = state.copyWith(phase: CapturePhase.stopping);
    _elapsedTimer?.cancel();
    _elapsedTimer = null;

    await _service.stopCapture();
    await WakelockPlus.disable();

    // Update note status to processing
    if (state.noteId != null) {
      ref
          .read(notesNotifierProvider.notifier)
          .updateNoteTitle(state.noteId!, state.noteId!); // trigger updatedAt
    }

    state = state.copyWith(phase: CapturePhase.previewing);
  }

  void setInterval(int seconds) {
    state = state.copyWith(intervalSeconds: seconds);
  }

  Future<void> cleanup() async {
    _elapsedTimer?.cancel();
    await _service.dispose();
    await WakelockPlus.disable();
    state = const CaptureState();
  }
}

final captureNotifierProvider =
    NotifierProvider<CaptureNotifier, CaptureState>(() => CaptureNotifier());
