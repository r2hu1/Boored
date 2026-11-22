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

    // Step 1: Find any completely clean frame (frame without person)
    for (final path in keyframePaths) {
      final mask = masks[path];
      if (mask == null || !mask.hasPerson) {
        latestCleanFrame = path;
        break;
      }
    }

    for (int i = 0; i < keyframePaths.length; i++) {
      final path = keyframePaths[i];
      final mask = masks[path];

      if (mask == null || !mask.hasPerson) {
        latestCleanFrame = path;
        cleanOutputs.add(path);
      } else {
        String? referenceFrame = (latestCleanFrame != null && latestCleanFrame != path)
            ? latestCleanFrame
            : null;

        // If no completely clean frame exists, find the candidate with minimum person overlap
        if (referenceFrame == null && keyframePaths.length > 1) {
          int minOverlap = 999999999;
          String? bestCandidate;
          int currPersonPixels = 0;
          for (final c in mask.confidences) {
            if (c > 0.15) currPersonPixels++;
          }

          for (final candidate in keyframePaths) {
            if (candidate == path) continue;
            final candMask = masks[candidate];
            if (candMask == null || !candMask.hasPerson) {
              bestCandidate = candidate;
              minOverlap = 0;
              break;
            }

            int overlap = 0;
            final limit = mask.confidences.length < candMask.confidences.length
                ? mask.confidences.length
                : candMask.confidences.length;
            for (int k = 0; k < limit; k++) {
              if (mask.confidences[k] > 0.15 && candMask.confidences[k] > 0.15) {
                overlap++;
              }
            }

            if (overlap < minOverlap) {
              minOverlap = overlap;
              bestCandidate = candidate;
            }
          }

          // Only use the candidate if overlap is low (<40% of person)
          // Otherwise, inpainting the original frame produces much cleaner whiteboard without ghost limbs
          if (bestCandidate != null && (currPersonPixels == 0 || minOverlap < currPersonPixels * 0.4)) {
            referenceFrame = bestCandidate;
          }
        }

        final refPath = (referenceFrame != null && referenceFrame != path)
            ? referenceFrame
            : path;

        final refMask = masks[refPath];

        final compositedPath = path.replaceAll('.jpg', '_deoccluded_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        final success = await openCVService.compositeUnoccluded(
          currentPath: path,
          cleanBackgroundPath: refPath,
          dstPath: compositedPath,
          maskConfidences: mask.confidences,
          maskWidth: mask.width,
          maskHeight: mask.height,
          bgMaskConfidences: refMask?.confidences,
          bgMaskWidth: refMask?.width,
          bgMaskHeight: refMask?.height,
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
