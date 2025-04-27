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
    List<String> lines = rawText.split('\n');
    List<String> addressLines = [];
    bool foundAddress = false;

    for (String line in lines) {
      line = line.trim();

      if (line.isEmpty) continue;

      final lowercaseLine = line.toLowerCase();

      // ❌ Skip clearly non-address lines (e.g., pure names without keywords)
      if (RegExp(r'^[A-Za-z\s]{3,}$').hasMatch(line) &&
          !lowercaseLine.contains('jalan') &&
          !lowercaseLine.contains('lorong') &&
          !lowercaseLine.contains('taman') &&
          !lowercaseLine.contains('desa') &&
          !lowercaseLine.contains('bandar') &&
          !lowercaseLine.contains('kg') &&
          !lowercaseLine.contains('kampung') &&
          !lowercaseLine.contains('pangsapuri') &&
          !lowercaseLine.contains('residensi') &&
          !lowercaseLine.contains('apartment') &&
          !lowercaseLine.contains('flat') &&
          !lowercaseLine.contains('universiti') &&
          !lowercaseLine.contains('menara') &&
          !lowercaseLine.contains('wisma') &&
          !lowercaseLine.contains('kompleks') &&
          !lowercaseLine.contains('kementerian') &&
          !lowercaseLine.contains('blok') &&
          !lowercaseLine.contains('bangunan') &&
          !lowercaseLine.contains('putrajaya') &&
          !lowercaseLine.contains('kuala')) {
        continue;
      }

      // ✅ Detect if line contains keywords normally associated with address
      if (RegExp(r'^(Jalan|Lorong|Lintasan|Lebuh|Persiaran|Taman|Desa|Bandar|Kg|Kampung|No\.?|Lot)\s',
                  caseSensitive: false)
              .hasMatch(line) ||
          RegExp(r'^(Pangsapuri|Residensi|Apartment|Kondominium|Flat|Perumahan|Kuarters|The|SouthKey|Sky|Tower)',
                  caseSensitive: false)
              .hasMatch(line) ||
          RegExp(r'^(Wisma|Menara|Kompleks|Pejabat|Bangunan|Blok|Kementerian)',
                  caseSensitive: false)
              .hasMatch(line) ||
          RegExp(r'^(Universiti|Sekolah|Kolej|Institut|Politeknik)',
                  caseSensitive: false)
              .hasMatch(line) ||
          RegExp(r'^[A-Za-z0-9]{1,3}[- ]\d{1,2}[- ]\d{1,3}[A-Za-z]?$',
                  caseSensitive: false)
              .hasMatch(line)) {
        addressLines.add(line);
        foundAddress = true;
        continue;
      }

      // ✅ Accept standalone city/state with or without comma
      if (RegExp(
              r'^[A-Za-z\s]+(,)?\s*(Selangor|Kuala Lumpur|Johor|Melaka|Terengganu|Pahang|Perak|Sabah|Sarawak)$',
              caseSensitive: false)
          .hasMatch(line)) {
        addressLines.add(line);
        foundAddress = true;
        continue;
      }

      // ✅ Remove postcode but keep city/district name
      if (RegExp(r'^\d{5}\s+[A-Za-z\s\.\-]+$', caseSensitive: false)
          .hasMatch(line)) {
        final cleaned = line.replaceFirst(RegExp(r'^\d{5}\s*'), '').trim();
        if (cleaned.isNotEmpty) {
          addressLines.add(cleaned);
          foundAddress = true;
        }
        continue;
      }

      // ✅ Smart fallback: accept long enough lines (3+ words) that look like places
      if (line.split(' ').length >= 3) {
        addressLines.add(line);
        foundAddress = true;
        continue;
      }

      // ✅ Accept if line contains "Malaysia"
      if (lowercaseLine.contains('malaysia')) {
        addressLines.add(line);
        foundAddress = true;
        continue;
      }
    }

    return foundAddress ? addressLines.join("\n") : "No valid address detected";
  }
}
