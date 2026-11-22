import 'dart:typed_data';

abstract class SegmentationEngine {
  Future<SegmentationMaskResult?> processImage(String imagePath);
  Future<void> dispose();
}

class SegmentationMaskResult {
  final int width;
  final int height;
  final List<double> confidences;

  const SegmentationMaskResult({
    required this.width,
    required this.height,
    required this.confidences,
  });

  bool get hasPerson {
    int count = 0;
    for (final c in confidences) {
      if (c > 0.15) count++;
    }
    // Person detected if more than 0.5% of total mask area has confidence > 0.15
    return count > (confidences.length * 0.005);
  }

  Uint8List toByteArray({double threshold = 0.15}) {
    final bytes = Uint8List(confidences.length);
    for (int i = 0; i < confidences.length; i++) {
      bytes[i] = confidences[i] > threshold ? 255 : 0;
    }
    return bytes;
  }
}
