abstract class RecognitionEngine {
  Future<String> extractText(String imagePath);
  Future<void> dispose();
}
