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

  // ✅ Custom filtering for Malaysian addresses (buildings, residential, etc.)
  String _filterAddressText(String rawText) {
    List<String> lines = rawText.split("\n");
    List<String> addressLines = [];
    bool foundAddress = false;

    for (String line in lines) {
      line = line.trim();

      // ❌ Skip likely personal names unless address-relevant keywords
      if (RegExp(r'^[A-Za-z\s]{3,}\$').hasMatch(line) &&
          !line.toLowerCase().contains("jalan") &&
          !line.toLowerCase().contains("taman") &&
          !line.toLowerCase().contains("pangsapuri") &&
          !line.toLowerCase().contains("residensi") &&
          !line.toLowerCase().contains("wisma") &&
          !line.toLowerCase().contains("menara") &&
          !line.toLowerCase().contains("pejabat") &&
          !line.toLowerCase().contains("bangunan") &&
          !line.toLowerCase().contains("kompleks") &&
          !line.toLowerCase().contains("blok") &&
          !line.toLowerCase().contains("kementerian")) {
        continue;
      }

      // ✅ Government/Institutional or Commercial Buildings
      if (RegExp(
              r'^(Wisma|Menara|Kompleks|Pejabat|Bangunan|Blok|Kementerian)\s.+',
              caseSensitive: false)
          .hasMatch(line)) {
        addressLines.add(line);
        foundAddress = true;
        continue;
      }

      // ✅ Residential & Landed Address (No., Lot, Taman, etc.)
      if (RegExp(r'^(No\.?|Lot|Rumah|Kampung|Kg)\s?\d+[A-Za-z\-/]*')
              .hasMatch(line) ||
          RegExp(r'^(Taman|Desa|Bandar|Kampung|Kg)\s.+', caseSensitive: false)
              .hasMatch(line)) {
        addressLines.add(line);
        foundAddress = true;
        continue;
      }

      // ✅ Street Name
      if (RegExp(r'^(Jalan|Lorong|Persiaran|Lebuh|Lintasan)',
              caseSensitive: false)
          .hasMatch(line)) {
        addressLines.add(line);
        foundAddress = true;
        continue;
      }

      // ✅ Apartment/Condo/Flat Names
      if (RegExp(
              r'^(Pangsapuri|Residensi|Apartment|Kondominium|Flat|Perumahan|Kuarters)\s.+',
              caseSensitive: false)
          .hasMatch(line)) {
        addressLines.add(line);
        foundAddress = true;
        continue;
      }

      // ✅ Educational Institutions
      if (RegExp(r'^(Universiti|Sekolah|Politeknik|Kolej|Institut)\s.+',
              caseSensitive: false)
          .hasMatch(line)) {
        addressLines.add(line);
        foundAddress = true;
        continue;
      }

      // ✅ Unit/Flat format (A-01-13B, B-3-10)
      if (RegExp(r'^[A-Za-z0-9]{1,3}[- ]\d{1,2}[- ]\d{1,3}[A-Za-z]?\$')
          .hasMatch(line)) {
        addressLines.add(line);
        foundAddress = true;
        continue;
      }

      // ✅ City & State format (e.g., Shah Alam, Selangor)
      if (RegExp(r'^[A-Za-z\s]+,\s?[A-Za-z\s]+\$').hasMatch(line)) {
        addressLines.add(line);
        foundAddress = true;
        continue;
      }

      // ✅ Standalone city detection (e.g., Putrajaya, Bangi, Kuching)
      if (RegExp(
              r'^(Putrajaya|Kuala Lumpur|Shah Alam|Petaling Jaya|Kuching|Seremban|Johor Bahru|Melaka|Bangi|Kajang|Ipoh|Kuantan|Kuala Terengganu)\$',
              caseSensitive: false)
          .hasMatch(line)) {
        addressLines.add(line);
        foundAddress = true;
        continue;
      }

      // ✅ Country
      if (line.toLowerCase().contains("malaysia")) {
        addressLines.add(line);
        foundAddress = true;
        continue;
      }

// ✅ Remove postcode but keep city/district after it
      if (RegExp(r'^\d{5}\s+[A-Za-z\s\.\-]+$', caseSensitive: false)
          .hasMatch(line)) {
        final cleaned = line.replaceFirst(RegExp(r'^\d{5}\s*'), '').trim();
        if (cleaned.isNotEmpty) {
          addressLines.add(cleaned);
          foundAddress = true;
        }
        continue;
      }

      // ❌ Skip postal code (5-digit)
      if (RegExp(r'^\d{5}\$').hasMatch(line)) {
        continue;
      }
    }

    return foundAddress ? addressLines.join("\n") : "No valid address detected";
  }
}
