import 'package:flutter/services.dart';
import '../presentation/widgets/board_overlay.dart';

class FrameChangeResult {
  final String eventType; // "ADD", "ERASE", "NONE"
  final double diffRatio;

  const FrameChangeResult({
    required this.eventType,
    required this.diffRatio,
  });
}

class OpenCVService {
  static const _channel = MethodChannel('com.boored.boored/opencv');

  Future<List<BoardCorner>> detectBoardCorners(String imagePath) async {
    try {
      final result = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'detectBoardCorners',
        {'imagePath': imagePath},
      );

      if (result == null || result.length != 4) {
        return _defaultCorners;
      }

      return result.map((item) {
        final x = (item['x'] as num).toDouble();
        final y = (item['y'] as num).toDouble();
        return BoardCorner(x, y);
      }).toList();
    } catch (_) {
      return _defaultCorners;
    }
  }

  Future<String?> warpPerspective({
    required String srcPath,
    required String dstPath,
    required List<BoardCorner> corners,
  }) async {
    try {
      final cornersMap = corners
          .map((c) => {'x': c.x, 'y': c.y})
          .toList(growable: false);

      final result = await _channel.invokeMethod<String>(
        'warpPerspective',
        {
          'srcPath': srcPath,
          'dstPath': dstPath,
          'corners': cornersMap,
        },
      );
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<String?> enhanceWhiteboard({
    required String srcPath,
    required String dstPath,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'enhanceWhiteboard',
        {
          'srcPath': srcPath,
          'dstPath': dstPath,
        },
      );
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<FrameChangeResult> detectFrameChange({
    required String prevPath,
    required String currPath,
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'detectFrameChange',
        {
          'prevPath': prevPath,
          'currPath': currPath,
        },
      );

      if (result == null) {
        return const FrameChangeResult(eventType: 'NONE', diffRatio: 0.0);
      }

      return FrameChangeResult(
        eventType: (result['eventType'] as String?) ?? 'NONE',
        diffRatio: ((result['diffRatio'] as num?) ?? 0.0).toDouble(),
      );
    } catch (_) {
      return const FrameChangeResult(eventType: 'NONE', diffRatio: 0.0);
    }
  }

  static const List<BoardCorner> _defaultCorners = [
    BoardCorner(0.08, 0.08),
    BoardCorner(0.92, 0.08),
    BoardCorner(0.92, 0.92),
    BoardCorner(0.08, 0.92),
  ];
}
