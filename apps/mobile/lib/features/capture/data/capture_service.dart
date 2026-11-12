import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CaptureService {
  CameraController? _controller;
  Timer? _captureTimer;
  bool _isCapturing = false;
  int _frameIndex = 0;
  String? _sessionDir;

  CameraController? get controller => _controller;
  bool get isCapturing => _isCapturing;
  int get frameCount => _frameIndex;

  Future<CameraController> initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No cameras found');

    // Prefer back camera
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
    return _controller!;
  }

  // Creates a timestamped directory under app-private storage for this session
  Future<String> _createSessionDir(String noteId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'captures', noteId));
    await dir.create(recursive: true);
    return dir.path;
  }

  Future<void> startCapture({
    required String noteId,
    Duration interval = const Duration(seconds: 5),
    void Function(int frameIndex, String path)? onFrameCaptured,
    void Function(Object error)? onError,
    bool resume = false,
  }) async {
    if (_isCapturing) return;
    if (_controller == null || !_controller!.value.isInitialized) {
      throw StateError('Camera not initialized');
    }

    _sessionDir = await _createSessionDir(noteId);
    if (!resume) {
      _frameIndex = 0;
    }
    _isCapturing = true;

    // Capture first frame immediately
    await _captureFrame(onFrameCaptured, onError);

    _captureTimer = Timer.periodic(interval, (_) async {
      if (!_isCapturing) return;
      await _captureFrame(onFrameCaptured, onError);
    });
  }

  Future<void> _captureFrame(
    void Function(int frameIndex, String path)? onFrameCaptured,
    void Function(Object error)? onError,
  ) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final xFile = await _controller!.takePicture();
      final destPath = p.join(
        _sessionDir!,
        'frame_${_frameIndex.toString().padLeft(5, '0')}.jpg',
      );
      await File(xFile.path).copy(destPath);
      await File(xFile.path).delete();

      onFrameCaptured?.call(_frameIndex, destPath);
      _frameIndex++;
    } catch (e) {
      onError?.call(e);
    }
  }

  Future<void> stopCapture() async {
    _isCapturing = false;
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  Future<void> dispose() async {
    await stopCapture();
    await _controller?.dispose();
    _controller = null;
  }

  // For crash recovery: list existing frames in a session directory
  static Future<List<String>> recoverFrames(String noteId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'captures', noteId));
    if (!await dir.exists()) return [];

    final files = await dir
        .list()
        .where((f) => f is File && f.path.endsWith('.jpg'))
        .map((f) => f.path)
        .toList();

    files.sort();
    return files;
  }
}
