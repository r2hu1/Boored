import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../domain/recognition_engine.dart';
import 'opencv_service.dart';

class MLKitRecognitionEngine implements RecognitionEngine {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final OpenCVService _openCVService = OpenCVService();

  @override
  Future<String> extractText(String imagePath) async {
    try {
      String pathForOcr = imagePath;
      final ocrPrepPath = imagePath.replaceAll('.jpg', '_ocrprep_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final preprocessed = await _openCVService.preprocessForOcr(
        srcPath: imagePath,
        dstPath: ocrPrepPath,
      );

      if (preprocessed != null && File(ocrPrepPath).existsSync()) {
        pathForOcr = ocrPrepPath;
      }

      final inputImage = InputImage.fromFile(File(pathForOcr));
      final recognizedText = await _recognizer.processImage(inputImage);

      // Clean up temporary OCR-preprocessed file if generated
      if (pathForOcr != imagePath && File(ocrPrepPath).existsSync()) {
        try {
          File(ocrPrepPath).deleteSync();
        } catch (_) {}
      }

      return recognizedText.text;
    } catch (_) {
      return '';
    }
  }

  @override
  Future<void> dispose() async {
    await _recognizer.close();
  }
}
