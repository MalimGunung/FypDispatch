import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class MLKitOCR {
  final textRecognizer = TextRecognizer();

  Future<String> extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      String extractedText = recognizedText.text;
      return _filterAddressText(extractedText);
    } catch (e) {
      print("OCR Error: $e");
      return "No text found";
    }
  }

  // ✅ Custom filtering for Malaysian residential addresses
  String _filterAddressText(String rawText) {
    List<String> lines = rawText.split("\n");
    List<String> addressLines = [];
    bool found = false;

    for (String line in lines) {
      line = line.trim();

      // Skip empty or overly short lines
      if (line.isEmpty || line.length < 3) continue;

      // ✅ Match unit/block pattern like "B-01-13A", "A-2-5"
      if (RegExp(r'^[A-Z]-\d{1,2}-\d{1,3}[A-Z]?$').hasMatch(line)) {
        found = true;
        addressLines.add(line);
        continue;
      }

      // ✅ Match building/area names: Pangsapuri, Taman, Residensi, Apartment, Flat, etc.
      if (RegExp(r'\b(Pangsapuri|Taman|Residensi|Apartment|Flat|Kondominium|Desa|Bandar)\b',
              caseSensitive: false)
          .hasMatch(line)) {
        found = true;
        addressLines.add(line);
        continue;
      }

      // ✅ Match city & state like "Kajang, Selangor"
      if (RegExp(r'^[A-Za-z\s]+,\s*[A-Za-z\s]+$').hasMatch(line)) {
        found = true;
        addressLines.add(line);
        continue;
      }

      // ✅ Optional: catch additional address elements (Jalan, Lorong, etc.)
      if (RegExp(r'^(Jalan|Lorong|Persiaran|Lebuhraya)', caseSensitive: false)
          .hasMatch(line)) {
        found = true;
        addressLines.add(line);
        continue;
      }
    }

    return found ? addressLines.join("\n") : "No valid address detected";
  }
}
