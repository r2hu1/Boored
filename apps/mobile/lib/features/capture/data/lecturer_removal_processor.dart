import 'dart:io';
import 'dart:typed_data';
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

    // Step 1: Compute and cache segmentation masks for all keyframes in the session
    final masks = <String, SegmentationMaskResult?>{};
    for (final path in keyframePaths) {
      masks[path] = await segmenter.processImage(path);
    }

    // Step 2: Process each frame using temporal multi-frame whiteboard reconstruction
    for (int i = 0; i < keyframePaths.length; i++) {
      final path = keyframePaths[i];
      final mask = masks[path];

      if (mask == null || !mask.hasPerson) {
        // Frame has no person; it is already clean whiteboard with original content
        cleanOutputs.add(path);
      } else {
        // Temporal ordering:
        // First look forward in time (i+1, i+2, ...) where writing is complete and lecturer moved aside,
        // then look backward in time (i-1, i-2, ...) where board was exposed prior to occlusion.
        final orderedCandidates = <String>[];
        for (int step = 1; step < keyframePaths.length; step++) {
          final forward = i + step;
          if (forward < keyframePaths.length) orderedCandidates.add(keyframePaths[forward]);
          final backward = i - step;
          if (backward >= 0) orderedCandidates.add(keyframePaths[backward]);
        }

        final candPaths = <String>[];
        final candMaskBytes = <Uint8List>[];

        for (final candPath in orderedCandidates) {
          final candMask = masks[candPath];
          candPaths.add(candPath);
          candMaskBytes.add(
            candMask != null
                ? candMask.toByteArray(threshold: 0.15)
                : Uint8List(0), // empty bytes = completely clean whiteboard frame
          );
        }

        final compositedPath = path.replaceAll('.jpg', '_deoccluded_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        final success = await openCVService.reconstructWhiteboard(
          currentPath: path,
          currentMaskBytes: mask.toByteArray(threshold: 0.15),
          maskWidth: mask.width,
          maskHeight: mask.height,
          candidatePaths: candPaths,
          candidateMaskBytesList: candMaskBytes,
          dstPath: compositedPath,
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
