import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class MLKitOCR {
  final textRecognizer = TextRecognizer();

  Future<String> extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      String extractedText = recognizedText.text;

      // Extract only address-like text
      return _filterAddressText(extractedText);
    } catch (e) {
      print("OCR Error: $e");
      return "No text found";
    }
  }

  // **Extracts Only Structured Addresses**
  String _filterAddressText(String rawText) {
    List<String> lines = rawText.split("\n");
    List<String> addressLines = [];
    bool foundAddress = false;

    for (String line in lines) {
      line = line.trim();

      // Detect and ignore personal names (e.g., "Ali Bin Ahmad")
      if (RegExp(r'^[A-Za-z\s]+$').hasMatch(line)) {
        continue;
      }

      // Detect House/Building No & Street (e.g., "No. 12, Lorong Damai 5")
      if (RegExp(r'^(No\.|Lot|Blok|Jalan|Lorong|Persiaran|Taman|Bandar|Lebuh)').hasMatch(line)) {
        foundAddress = true;
        addressLines.add(line);
      }

      // Detect Postal Code & City (e.g., "81100 Johor Bahru, Johor")
      if (RegExp(r'^\d{5}').hasMatch(line)) {
        foundAddress = true;
        addressLines.add(line);
      }

      // Detect Country (e.g., "Malaysia")
      if (line.toLowerCase().contains("malaysia")) {
        foundAddress = true;
        addressLines.add(line);
      }
    }

    return foundAddress ? addressLines.join("\n") : "No valid address detected";
  }
}
