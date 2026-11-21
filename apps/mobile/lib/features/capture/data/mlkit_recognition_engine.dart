import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../domain/recognition_engine.dart';

class MLKitRecognitionEngine implements RecognitionEngine {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String> extractText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFile(File(imagePath));
      final recognizedText = await _recognizer.processImage(inputImage);

      // Build full text from all blocks preserving spatial layout
      final buffer = StringBuffer();
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
        }
        buffer.writeln();
      }

      return buffer.toString().trimRight();
    } catch (_) {
      return '';
    }
  }

  @override
  Future<void> dispose() async {
    await _recognizer.close();
  }
}
