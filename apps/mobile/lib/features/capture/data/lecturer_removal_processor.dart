import 'dart:io';
import '../domain/segmentation_engine.dart';
import 'opencv_service.dart';

class LecturerRemovalProcessor {
  final SegmentationEngine segmenter;
  final OpenCVService openCVService;

  const LecturerRemovalProcessor({
    required this.segmenter,
    required this.openCVService,
  });

  Future<List<String>> processKeyframeSequence(List<String> keyframePaths) async {
    final cleanOutputs = <String>[];
    String? latestCleanFrame;

    for (int i = 0; i < keyframePaths.length; i++) {
      final path = keyframePaths[i];
      final mask = await segmenter.processImage(path);

      if (mask == null || !mask.hasPerson) {
        latestCleanFrame = path;
        cleanOutputs.add(path);
      } else {
        if (latestCleanFrame != null) {
          final compositedPath = path.replaceAll('.jpg', '_deoccluded.jpg');
          final success = await openCVService.compositeUnoccluded(
            currentPath: path,
            cleanBackgroundPath: latestCleanFrame,
            dstPath: compositedPath,
            maskConfidences: mask.confidences,
            maskWidth: mask.width,
            maskHeight: mask.height,
          );

          if (success != null && File(compositedPath).existsSync()) {
            cleanOutputs.add(compositedPath);
            try {
              await File(path).delete();
            } catch (_) {}
          } else {
            cleanOutputs.add(latestCleanFrame);
          }
        } else {
          cleanOutputs.add(path);
        }
      }
    }

    return cleanOutputs;
  }
}
