import 'package:flutter/services.dart';
import '../presentation/widgets/board_overlay.dart';

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

  static const List<BoardCorner> _defaultCorners = [
    BoardCorner(0.08, 0.08),
    BoardCorner(0.92, 0.08),
    BoardCorner(0.92, 0.92),
    BoardCorner(0.08, 0.92),
  ];
}
