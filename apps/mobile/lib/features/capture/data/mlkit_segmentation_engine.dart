import 'dart:io';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import '../domain/segmentation_engine.dart';

class MLKitSegmentationEngine implements SegmentationEngine {
  final SelfieSegmenter _segmenter = SelfieSegmenter(
    mode: SegmenterMode.single,
    enableRawSizeMask: false,
  );

  @override
  Future<SegmentationMaskResult?> processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFile(File(imagePath));
      final mask = await _segmenter.processImage(inputImage);
      if (mask == null) return null;

      return SegmentationMaskResult(
        width: mask.width,
        height: mask.height,
        confidences: mask.confidences,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    await _segmenter.close();
  }
}
