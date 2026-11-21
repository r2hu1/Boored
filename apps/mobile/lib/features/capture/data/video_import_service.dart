import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class VideoFrameExtractionResult {
  final List<String> framePaths;
  final int durationMs;

  const VideoFrameExtractionResult({
    required this.framePaths,
    required this.durationMs,
  });
}

class VideoImportService {
  static const _channel = MethodChannel('com.boored.boored/opencv');

  /// Extracts frames from [videoPath] at [intervalMs] intervals.
  /// Saves JPEGs into the note's capture directory and returns frame paths + video duration.
  Future<VideoFrameExtractionResult> extractFrames({
    required String videoPath,
    required String noteId,
    int intervalMs = 5000,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final outputDir = p.join(appDir.path, 'captures', noteId);
    await Directory(outputDir).create(recursive: true);

    final result = await _channel.invokeMapMethod<String, dynamic>(
      'extractVideoFrames',
      {
        'videoPath': videoPath,
        'outputDir': outputDir,
        'intervalMs': intervalMs,
      },
    );

    if (result == null) {
      throw Exception('Failed to extract frames from video');
    }

    final framePaths = (result['framePaths'] as List<dynamic>)
        .cast<String>()
        .where((path) => File(path).existsSync())
        .toList();
    final durationMs = (result['durationMs'] as num?)?.toInt() ?? 0;

    return VideoFrameExtractionResult(
      framePaths: framePaths,
      durationMs: durationMs,
    );
  }
}
