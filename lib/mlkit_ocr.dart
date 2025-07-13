import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class EnhancedMLKitOCR {
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

  String _filterAddressText(String rawText) {
    List<String> lines = rawText.split('\n');
    List<String> addressLines = [];
    bool foundAddress = false;
    
    // Clean and normalize lines
    lines = lines.map((line) => _cleanLine(line)).where((line) => line.isNotEmpty).toList();
    
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      String lowercaseLine = line.toLowerCase();
      
      // Skip obvious non-address content
      if (_shouldSkipLine(line, lowercaseLine)) {
        continue;
      }
      
      // Check various address patterns
      if (_isAddressLine(line, lowercaseLine, i, lines)) {
        addressLines.add(line);
        foundAddress = true;
      }
    }
    
    // Post-process to clean up and validate the address
    addressLines = _postProcessAddress(addressLines);
    
    return foundAddress && addressLines.isNotEmpty 
        ? addressLines.join("\n") 
        : "No valid address detected";
  }

  String _cleanLine(String line) {
    // Remove excessive whitespace and normalize
    line = line.trim();
    line = line.replaceAll(RegExp(r'\s+'), ' ');
    
    // Fix common OCR mistakes for Malaysian text
    line = line.replaceAll(RegExp(r'[|\\]'), 'l');
    line = line.replaceAll(RegExp(r'[0O]'), '0');
    line = line.replaceAll('Ja1an', 'Jalan');
    line = line.replaceAll('Ja|an', 'Jalan');
    line = line.replaceAll('Kg.', 'Kg');
    line = line.replaceAll('Tmn', 'Taman');
    line = line.replaceAll('Pjs', 'PJS');
    
    return line;
  }

  bool _shouldSkipLine(String line, String lowercaseLine) {
    // Skip very short lines
    if (line.length < 3) return true;
    
    // Skip lines that are clearly not addresses
    List<String> skipPatterns = [
      r'^\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}$', // Dates
      r'^[+]?\d{10,15}$', // Phone numbers
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', // Emails
      r'^(mr|mrs|ms|dr|prof|datuk|dato|tan sri|tun)[\s\.]', // Titles
      r'^(terima kasih|thank you|regards|sincerely)$', // Closings
      r'^\d{1,2}:\d{2}(\s?(am|pm))?$', // Times
    ];
    
    for (String pattern in skipPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(line)) {
        return true;
      }
    }
    
    return false;
  }

  bool _isAddressLine(String line, String lowercaseLine, int index, List<String> allLines) {
    // 1. Street prefixes (most common)
    List<String> streetPrefixes = [
      r'^(jalan|jln|lorong|lrg|lintasan|lebuh|persiaran|jalan raya)',
      r'^(tingkat|tkt|aras|tingkat mesra|ground floor|1st floor)',
      r'^(no\.?\s*\d+|lot\s*\d+|plot\s*\d+)',
    ];
    
    for (String prefix in streetPrefixes) {
      if (RegExp(prefix, caseSensitive: false).hasMatch(line)) {
        return true;
      }
    }
    
    // 2. Building/Housing types
    List<String> buildingTypes = [
      r'^(pangsapuri|apartment|apt|kondominium|kondo|condo)',
      r'^(residensi|residency|residence|villa|terrace|teres)',
      r'^(flat|rumah|house|home|townhouse|bungalow)',
      r'^(menara|tower|wisma|kompleks|plaza|mall)',
      r'^(pejabat|office|kedai|shop|shoplot|ruko)',
      r'^(bangunan|building|blok|block|unit)',
      r'^(the\s+\w+|southkey|sky\s+\w+|garden|taman)',
      r'^(kuarters|quarters|mess|hostel|asrama)',
    ];
    
    for (String building in buildingTypes) {
      if (RegExp(building, caseSensitive: false).hasMatch(line)) {
        return true;
      }
    }
    
    // 3. Area/District names
    List<String> areaKeywords = [
      r'(taman|tmn|desa|bandar|kampung|kg|seksyen|section)',
      r'(pjs|ss|usj|subang|shah alam|petaling|damansara)',
      r'(bukit|hill|heights|garden|park|city|town)',
      r'(indah|jaya|utama|perdana|mega|prima|cemerlang)',
      r'(sentral|central|square|avenue|walk|mall)',
    ];
    
    for (String area in areaKeywords) {
      if (RegExp(area, caseSensitive: false).hasMatch(lowercaseLine)) {
        return true;
      }
    }
    
    // 4. Malaysian states and federal territories
    List<String> states = [
      'selangor', 'kuala lumpur', 'kl', 'johor', 'melaka', 'malacca',
      'negeri sembilan', 'pahang', 'terengganu', 'kelantan', 'perak',
      'penang', 'pulau pinang', 'kedah', 'perlis', 'sabah', 'sarawak',
      'putrajaya', 'labuan', 'cyberjaya', 'petaling jaya', 'pj',
      'shah alam', 'klang', 'subang jaya', 'ampang', 'cheras',
      'kajang', 'serdang', 'puchong', 'setapak', 'wangsa maju'
    ];
    
    for (String state in states) {
      if (lowercaseLine.contains(state)) {
        return true;
      }
    }
    
    // 5. Postcode patterns (with or without city)
    if (RegExp(r'^\d{5}(\s+[a-zA-Z\s\.\-,]+)?$').hasMatch(line)) {
      return true;
    }
    
    // 6. Unit/House numbers
    if (RegExp(r'^[A-Za-z]?[\-\s]*\d{1,4}[\-\s]*\d{0,3}[A-Za-z]?[\-\s]*\d{0,3}[A-Za-z]?$').hasMatch(line)) {
      return true;
    }
    
    // 7. Road numbers and coordinates
    if (RegExp(r'^(km\s*\d+|mile\s*\d+|\d+\s*km|\d+\s*mile)').hasMatch(lowercaseLine)) {
      return true;
    }
    
    // 8. Educational institutions
    List<String> institutions = [
      r'(universiti|university|sekolah|school|kolej|college)',
      r'(institut|institute|politeknik|polytechnic|akademi)',
      r'(uitm|um|upm|utm|usm|utp|mmu|help|taylor)',
    ];
    
    for (String inst in institutions) {
      if (RegExp(inst, caseSensitive: false).hasMatch(lowercaseLine)) {
        return true;
      }
    }
    
    // 9. Government/Corporate buildings
    if (RegExp(r'(kementerian|ministry|jabatan|department|perbadanan|corporation)', 
              caseSensitive: false).hasMatch(lowercaseLine)) {
      return true;
    }
    
    // 10. Context-based detection (if surrounded by address-like lines)
    if (_hasAddressContext(index, allLines)) {
      // If it has 2+ words and reasonable length, likely part of address
      if (line.split(' ').length >= 2 && line.length >= 5 && line.length <= 100) {
        return true;
      }
    }
    
    // 11. Malaysia country indicator
    if (lowercaseLine.contains('malaysia')) {
      return true;
    }
    
    return false;
  }

  bool _hasAddressContext(int currentIndex, List<String> lines) {
    int contextRange = 2;
    int addressLikeCount = 0;
    
    int start = (currentIndex - contextRange).clamp(0, lines.length);
    int end = (currentIndex + contextRange + 1).clamp(0, lines.length);
    
    for (int i = start; i < end; i++) {
      if (i == currentIndex) continue;
      
      String line = lines[i].toLowerCase();
      
      // Quick check for obvious address indicators
      if (line.contains('jalan') || line.contains('taman') || 
          line.contains('bandar') || RegExp(r'\d{5}').hasMatch(line) ||
          line.contains('selangor') || line.contains('kuala lumpur')) {
        addressLikeCount++;
      }
    }
    
    return addressLikeCount >= 1;
  }

  List<String> _postProcessAddress(List<String> addressLines) {
    List<String> cleaned = [];
    
    for (String line in addressLines) {
      // Skip duplicates
      if (cleaned.contains(line)) continue;
      
      // Handle postcode extraction/cleaning
      if (RegExp(r'^\d{5}\s+(.+)$').hasMatch(line)) {
        String match = RegExp(r'^\d{5}\s+(.+)$').firstMatch(line)!.group(1)!;
        if (match.trim().isNotEmpty) {
          cleaned.add(match.trim());
        }
      } else {
        cleaned.add(line);
      }
    }
    
    // Sort lines to put building/unit numbers first, then street, then area/city
    cleaned.sort((a, b) {
      int scoreA = _getAddressLineScore(a);
      int scoreB = _getAddressLineScore(b);
      return scoreA.compareTo(scoreB);
    });
    
    return cleaned;
  }

  int _getAddressLineScore(String line) {
    String lower = line.toLowerCase();
    
    // Unit/Building numbers come first
    if (RegExp(r'^[A-Za-z]?[\-\s]*\d').hasMatch(line)) return 1;
    if (lower.startsWith('unit') || lower.startsWith('tingkat')) return 1;
    
    // Building names
    if (lower.contains('apartment') || lower.contains('pangsapuri') || 
        lower.contains('menara') || lower.contains('wisma')) {
      return 2;
    }
    
    // Street addresses
    if (lower.startsWith('jalan') || lower.startsWith('lorong') || 
        lower.startsWith('no')) {
      return 3;
    }
    
    // Areas/Districts
    if (lower.contains('taman') || lower.contains('bandar') || 
        lower.contains('seksyen')) {
      return 4;
    }
    
    // Cities/States
    if (lower.contains('selangor') || lower.contains('kuala lumpur') || 
        lower.contains('johor')) {
      return 5;
    }
    
    // Country
    if (lower.contains('malaysia')) return 6;
    
    return 3; // Default to middle priority
  }
}