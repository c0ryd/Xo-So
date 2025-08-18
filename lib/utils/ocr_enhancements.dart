import 'dart:math' as math;

/// Enhanced OCR text processing specifically for Vietnamese lottery tickets
class OCREnhancements {
  
  /// Vietnamese province names with common OCR variations
  static final Map<String, List<String>> provinceVariations = {
    'An Giang': ['AN GIANG', 'ANGIANG', 'AN6IANG', 'AN GIAN6', 'ANGI4NG'],
    'Bac Lieu': ['BAC LIEU', 'BACLIEU', 'BAC IIEU', 'B4C LIEU', 'B4CLIEU'],
    'Ben Tre': ['BEN TRE', 'BENTRE', 'BEN IRE', 'BENTPE', 'B3N TRE'],
    'Binh Duong': ['BINH DUONG', 'BINHDUONG', 'BINH DU0NG', 'BINH DU0N6'],
    'Binh Phuoc': ['BINH PHUOC', 'BINHPHUOC', 'BINH PHU0C', 'BINH PHIOC'],
    'Binh Thuan': ['BINH THUAN', 'BINHTHUAN', 'BINH THIAN', 'BINH THU4N'],
    'Ca Mau': ['CA MAU', 'CAMAU', 'C4 MAU', 'CA M4U', 'CAMSU'],
    'Can Tho': ['CAN THO', 'CANTHO', 'C4N THO', 'CAN TH0', 'CANTH0'],
    'Cao Bang': ['CAO BANG', 'CAOBANG', 'C40 BANG', 'CAO B4NG'],
    'Da Lat': ['DA LAT', 'DALAT', 'D4 LAT', 'DA L4T', 'DMLAT'],
    'Da Nang': ['DA NANG', 'DANANG', 'D4 NANG', 'DA N4NG', 'DANN6'],
    'Dac Lac': ['DAC LAC', 'DACLAC', 'D4C LAC', 'DAC L4C', 'DACLSC'],
    'Dong Nai': ['DONG NAI', 'DONGNAI', 'D0NG NAI', 'DONG N4I'],
    'Dong Thap': ['DONG THAP', 'DONGTHAP', 'D0NG THAP', 'DONG TH4P'],
    'Gia Lai': ['GIA LAI', 'GIALAI', 'GI4 LAI', 'GIA L4I', '6IA LAI'],
    'Ha Noi': ['HA NOI', 'HANOI', 'H4 NOI', 'HA N0I', 'H4NOI'],
    'Hai Phong': ['HAI PHONG', 'HAIPHONG', 'H4I PHONG', 'HAI PH0NG'],
    'Hau Giang': ['HAU GIANG', 'HAUGIANG', 'H4U GIANG', 'HAU GI4NG'],
    'Ho Chi Minh': ['HO CHI MINH', 'HOCHIMINH', 'H0 CHI MINH', 'TP HCM', 'TPHCM', 'SAIGON'],
    'Hoa Binh': ['HOA BINH', 'HOABINH', 'H04 BINH', 'HOA BINH'],
    'Hung Yen': ['HUNG YEN', 'HUNGYEN', 'HUNG Y3N', 'HUN6 YEN'],
    'Khanh Hoa': ['KHANH HOA', 'KHANHHOA', 'KHANH H04', 'KH4NH HOA'],
    'Kien Giang': ['KIEN GIANG', 'KIENGIANG', 'KI3N GIANG', 'KIEN GI4NG'],
    'Kon Tum': ['KON TUM', 'KONTUM', 'K0N TUM', 'KON TlM'],
    'Lai Chau': ['LAI CHAU', 'LAICHAU', 'L4I CHAU', 'LAI CH4U'],
    'Lam Dong': ['LAM DONG', 'LAMDONG', 'L4M DONG', 'LAM D0NG'],
    'Lang Son': ['LANG SON', 'LANGSON', 'L4NG SON', 'LANG S0N'],
    'Lao Cai': ['LAO CAI', 'LAOCAI', 'L40 CAI', 'LAO C4I'],
    'Long An': ['LONG AN', 'LONGAN', 'L0NG AN', 'LONG 4N'],
    'Nam Dinh': ['NAM DINH', 'NAMDINH', 'N4M DINH', 'NAM DINH'],
    'Nghe An': ['NGHE AN', 'NGHEAN', 'NGH3 AN', 'NGHE 4N'],
    'Ninh Thuan': ['NINH THUAN', 'NINHTHUAN', 'NINH THU4N', 'NINH TH14N'],
    'Phu Yen': ['PHU YEN', 'PHUYEN', 'PHI YEN', 'PH1 YEN'],
    'Quang Binh': ['QUANG BINH', 'QUANGBINH', 'QU4NG BINH', 'QUANG BINH'],
    'Quang Nam': ['QUANG NAM', 'QUANGNAM', 'QU4NG NAM', 'QUANG N4M'],
    'Quang Ngai': ['QUANG NGAI', 'QUANGNGAI', 'QU4NG NGAI', 'QUANG NG4I'],
    'Quang Ninh': ['QUANG NINH', 'QUANGNINH', 'QU4NG NINH', 'QUANG NINH'],
    'Quang Tri': ['QUANG TRI', 'QUANGTRI', 'QU4NG TRI', 'QUANG TRI'],
    'Soc Trang': ['SOC TRANG', 'SOCTRANG', 'S0C TRANG', 'SOC TR4NG'],
    'Son La': ['SON LA', 'SONLA', 'S0N LA', 'SON L4'],
    'Tay Ninh': ['TAY NINH', 'TAYNINH', 'T4Y NINH', 'TAY NINH'],
    'Thai Binh': ['THAI BINH', 'THAIBINH', 'TH4I BINH', 'THAI BINH'],
    'Thai Nguyen': ['THAI NGUYEN', 'THAINGUYEN', 'TH4I NGUYEN', 'THAI NGU1EN'],
    'Thanh Hoa': ['THANH HOA', 'THANHHOA', 'TH4NH HOA', 'THANH H04'],
    'Thua Thien Hue': ['THUA THIEN HUE', 'THUATHIENHUE', 'HUE', 'THU4 THIEN HUE'],
    'Tien Giang': ['TIEN GIANG', 'TIENGIANG', 'TI3N GIANG', 'TIEN GI4NG'],
    'Tra Vinh': ['TRA VINH', 'TRAVINH', 'TR4 VINH', 'TRA VINH'],
    'Tuyen Quang': ['TUYEN QUANG', 'TUYENQUANG', 'TUY3N QUANG', 'TUYEN QU4NG'],
    'Vinh Long': ['VINH LONG', 'VINHLONG', 'VINH L0NG', 'VINH L0N6'],
    'Vinh Phuc': ['VINH PHUC', 'VINHPHUC', 'VINH PHIC', 'VINH PHlC'],
    'Yen Bai': ['YEN BAI', 'YENBAI', 'Y3N BAI', 'YEN B4I'],
    'Vung Tau': ['VUNG TAU', 'VUNGTAU', 'VlNG TAU', 'VUNG T4U'],
  };
  
  /// Enhanced province detection with OCR error tolerance
  static String findProvinceInText(String text) {
    final upperText = text.toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ')  // Remove special chars
        .replaceAll(RegExp(r'\s+'), ' ')           // Normalize spaces
        .trim();
    
    print('🔍 Enhanced province search in: "$upperText"');
    
    // Direct substring matching with variations
    for (final entry in provinceVariations.entries) {
      final province = entry.key;
      final variations = entry.value;
      
      for (final variation in variations) {
        if (upperText.contains(variation)) {
          print('✅ Found province "$province" via variation "$variation"');
          return province;
        }
      }
    }
    
    // Fuzzy matching for partial OCR failures
    String bestMatch = 'Not found';
    double bestScore = 0.0;
    
    for (final entry in provinceVariations.entries) {
      final province = entry.key;
      final mainVariation = entry.value.first; // Use the main variation
      
      final score = _fuzzyMatch(upperText, mainVariation);
      if (score > bestScore && score > 0.6) { // Lower threshold for fuzzy matching
        bestScore = score;
        bestMatch = province;
      }
    }
    
    if (bestMatch != 'Not found') {
      print('✅ Found province "$bestMatch" via fuzzy matching (score: $bestScore)');
    } else {
      print('❌ No province found in text');
    }
    
    return bestMatch;
  }
  
  /// Enhanced date detection with OCR error tolerance
  static String findDateInText(String text) {
    final upperText = text.toUpperCase().replaceAll(RegExp(r'[^0-9\-/\s]'), ' ');
    
    // Common date patterns with OCR variations
    final datePatterns = [
      RegExp(r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{4})\b'),     // DD-MM-YYYY or DD/MM/YYYY
      RegExp(r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{2})\b'),     // DD-MM-YY or DD/MM/YY
      RegExp(r'\b(\d{4})[-/](\d{1,2})[-/](\d{1,2})\b'),     // YYYY-MM-DD
      RegExp(r'\b(\d{1,2})\s+(\d{1,2})\s+(\d{4})\b'),       // DD MM YYYY with spaces
    ];
    
    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(upperText);
      if (match != null) {
        String dateStr = match.group(0)!;
        // Clean up the date string
        dateStr = dateStr.replaceAll(RegExp(r'\s+'), '-').replaceAll('/', '-');
        print('✅ Found date: $dateStr');
        return dateStr;
      }
    }
    
    print('❌ No date found in text');
    return 'Not found';
  }
  
  /// Enhanced ticket number detection
  static String findTicketNumberInText(String text) {
    // Look for sequences of 5-6 digits
    final numberPatterns = [
      RegExp(r'\b(\d{6})\b'),      // 6-digit numbers
      RegExp(r'\b(\d{5})\b'),      // 5-digit numbers
      RegExp(r'(\d{2}\s*\d{3})\b'), // Split numbers like "12 345"
      RegExp(r'(\d{3}\s*\d{3})\b'), // Split numbers like "123 456"
    ];
    
    for (final pattern in numberPatterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        String number = match.group(0)!.replaceAll(RegExp(r'\s+'), '');
        if (number.length >= 5) {
          print('✅ Found ticket number: $number');
          return number;
        }
      }
    }
    
    print('❌ No ticket number found');
    return 'Not found';
  }
  
  /// Simple fuzzy string matching
  static double _fuzzyMatch(String text, String pattern) {
    if (text.isEmpty || pattern.isEmpty) return 0.0;
    
    // Simple approach: count character overlaps
    int matches = 0;
    int patternIndex = 0;
    
    for (int i = 0; i < text.length && patternIndex < pattern.length; i++) {
      if (text[i] == pattern[patternIndex]) {
        matches++;
        patternIndex++;
      }
    }
    
    return matches / pattern.length;
  }
  
  /// Clean OCR text for better processing
  static String cleanOCRText(String text) {
    return text
        .toUpperCase()
        // Fix common OCR mistakes
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')  
        .replaceAll('5', 'S')
        .replaceAll('8', 'B')
        .replaceAll('6', 'G')
        // Vietnamese character fixes
        .replaceAll('Ơ', 'O')
        .replaceAll('Ư', 'U')
        .replaceAll('Đ', 'D')
        // Remove extra spaces
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
  
  /// Score OCR result quality for voting
  static double scoreOCRResult(String text, String city, String date, String ticketNumber) {
    double score = 0.0;
    
    // Base score for text length
    score += math.min(text.length * 0.1, 10.0);
    
    // High bonuses for finding each field
    if (city != 'Not found') score += 30.0;
    if (date != 'Not found') score += 25.0;
    if (ticketNumber != 'Not found') score += 35.0;
    
    // Bonus for numbers in text (lottery tickets have many numbers)
    final numbers = RegExp(r'\d+').allMatches(text);
    score += math.min(numbers.length * 2.0, 20.0);
    
    return score;
  }
}
