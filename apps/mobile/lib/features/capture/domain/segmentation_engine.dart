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

  bool get hasPerson => confidences.any((c) => c > 0.65);
}
