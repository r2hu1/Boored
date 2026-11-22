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

    // Cache masks so we only compute MLKit segmentation once per image
    final masks = <String, SegmentationMaskResult?>{};
    for (final path in keyframePaths) {
      masks[path] = await segmenter.processImage(path);
    }

    // Step 1: Find the best clean frame (first frame without person)
    for (final path in keyframePaths) {
      final mask = masks[path];
      if (mask == null || !mask.hasPerson) {
        latestCleanFrame = path;
        break;
      }
    }

    // Fallback: If ALL frames have a person, pick the frame with least person coverage
    if (latestCleanFrame == null && keyframePaths.isNotEmpty) {
      String bestPath = keyframePaths.first;
      int minPersonPixels = 999999999;
      for (final path in keyframePaths) {
        final mask = masks[path];
        if (mask != null) {
          final count = mask.confidences.where((c) => c > 0.25).length;
          if (count < minPersonPixels) {
            minPersonPixels = count;
            bestPath = path;
          }
        }
      }
      latestCleanFrame = bestPath;
    }

    for (int i = 0; i < keyframePaths.length; i++) {
      final path = keyframePaths[i];
      final mask = masks[path];

      if (mask == null || !mask.hasPerson) {
        latestCleanFrame = path;
        cleanOutputs.add(path);
      } else {
        // Find best reference frame: prefer latestCleanFrame, otherwise search any frame where person was in a different spot
        String? referenceFrame = (latestCleanFrame != null && latestCleanFrame != path)
            ? latestCleanFrame
            : null;

        if (referenceFrame == null) {
          for (final candidate in keyframePaths) {
            if (candidate != path) {
              referenceFrame = candidate;
              break;
            }
          }
        }

        // If no separate clean reference frame exists, refPath is path itself,
        // which triggers native Telea inpainting on the whiteboard occlusion mask
        final refPath = (referenceFrame != null && referenceFrame != path)
            ? referenceFrame
            : path;

        final compositedPath = path.replaceAll('.jpg', '_deoccluded_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        final success = await openCVService.compositeUnoccluded(
          currentPath: path,
          cleanBackgroundPath: refPath,
          dstPath: compositedPath,
          maskConfidences: mask.confidences,
          maskWidth: mask.width,
          maskHeight: mask.height,
        );

        if (success != null && File(compositedPath).existsSync()) {
          cleanOutputs.add(compositedPath);
        } else {
          cleanOutputs.add(path);
        }
      }
    }

    return cleanOutputs;
  }
}
