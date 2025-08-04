import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

// Custom painter for lottery ticket overlay frame
class LotteryTicketOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Calculate lottery ticket frame (centered, portrait rectangle) - optimized for focus
    final double frameHeight = size.height * 0.7;
    final double frameWidth = frameHeight * 0.6; // Portrait aspect ratio for lottery tickets
    final double left = (size.width - frameWidth) / 2;
    final double top = (size.height - frameHeight) / 2;
    
    final frameRect = Rect.fromLTWH(left, top, frameWidth, frameHeight);
    
    // Create overlay path that covers everything except the frame
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(frameRect)
      ..fillType = PathFillType.evenOdd; // This creates the hole
    
    // Draw semi-transparent overlay with hole in center
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5);
    canvas.drawPath(overlayPath, shadowPaint);
    
    // Draw the frame border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRect(frameRect, borderPaint);
    
    // Draw corner guides
    final cornerLength = 20.0;
    final cornerPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    
    // Top-left corner
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left, top + cornerLength), cornerPaint);
    
    // Top-right corner
    canvas.drawLine(Offset(left + frameWidth, top), Offset(left + frameWidth - cornerLength, top), cornerPaint);
    canvas.drawLine(Offset(left + frameWidth, top), Offset(left + frameWidth, top + cornerLength), cornerPaint);
    
    // Bottom-left corner
    canvas.drawLine(Offset(left, top + frameHeight), Offset(left + cornerLength, top + frameHeight), cornerPaint);
    canvas.drawLine(Offset(left, top + frameHeight), Offset(left, top + frameHeight - cornerLength), cornerPaint);
    
    // Bottom-right corner
    canvas.drawLine(Offset(left + frameWidth, top + frameHeight), Offset(left + frameWidth - cornerLength, top + frameHeight), cornerPaint);
    canvas.drawLine(Offset(left + frameWidth, top + frameHeight), Offset(left + frameWidth, top + frameHeight - cornerLength), cornerPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vietnamese Lottery OCR',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LotteryOCRScreen(),
    );
  }
}

class LotteryOCRScreen extends StatefulWidget {
  @override
  _LotteryOCRScreenState createState() => _LotteryOCRScreenState();
}

class _LotteryOCRScreenState extends State<LotteryOCRScreen> {
  final TextRecognizer _textRecognizer = TextRecognizer();
  CameraController? _cameraController;
  
  String city = 'Not found';
  String date = 'Not found';
  String ticketNumber = 'Not found';
  String rawText = '';
  bool isProcessing = false;
  bool _isCameraInitialized = false;
  String? _capturedImagePath;
  String? _processedImagePath; // Store the cropped/rotated image path
  
  // Cities data loaded from JSON
  Map<String, dynamic> _citiesData = {};
  List<String> _allCities = [];

  @override
  void initState() {
    super.initState();
    _loadCitiesData();
    // Don't initialize camera automatically - wait for user to click button
  }
  
  Future<void> _loadCitiesData() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/cities.json');
      _citiesData = json.decode(jsonString);
      
      // Extract all city names into a flat list
      _allCities = [];
      for (final region in _citiesData['regions']) {
        for (final city in region['cities']) {
          _allCities.add(city.toString());
        }
      }
      print('Loaded ${_allCities.length} cities from JSON');
    } catch (e) {
      print('Error loading cities data: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (cameras.isNotEmpty) {
      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.veryHigh, // Use highest resolution for better OCR
        enableAudio: false, // Disable audio to avoid microphone permission issues
      );
      
      try {
        await _cameraController!.initialize();
        
        // Set focus mode for better image quality
        await _cameraController!.setFocusMode(FocusMode.auto);
        
        setState(() {
          _isCameraInitialized = true;
        });
      } catch (e) {
        print('Error initializing camera: $e');
      }
    }
  }

  Future<void> _takePictureAndProcess() async {
    // Initialize camera if not already done
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await _initializeCamera();
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        return;
      }
      // Return here to let user see camera preview before taking picture
      return;
    }

    try {
      setState(() {
        isProcessing = true;
        // Reset previous results
        city = 'Not found';
        date = 'Not found';
        ticketNumber = 'Not found';
        rawText = '';
      });

      print('=== MULTI-SHOT VOTING STARTED ===');
      
      // Take 3 pictures with different exposure compensations for better OCR accuracy
      final List<Map<String, dynamic>> ocrResults = [];
      final exposureOffsets = [-1.0, 0.0, 1.0]; // Underexposed, normal, overexposed
      
      for (int i = 0; i < 3; i++) {
        try {
          // Set different exposure compensation
          await _cameraController!.setExposureOffset(exposureOffsets[i]);
          await Future.delayed(Duration(milliseconds: 200)); // Let exposure settle
          
          print('Taking shot ${i + 1}/3 with exposure ${exposureOffsets[i]}');
          
          // Take picture
          final XFile picture = await _cameraController!.takePicture();
          
          // Save the first captured image path for display
          if (i == 1) { // Use the normal exposure image for display
            _capturedImagePath = picture.path;
          }
          
          // Process this image
          final processedResult = await _processSingleImage(picture);
          if (processedResult != null) {
            ocrResults.add(processedResult);
          }
          
        } catch (e) {
          print('Error with shot ${i + 1}: $e');
        }
      }
      
      // Reset exposure to normal
      await _cameraController!.setExposureOffset(0.0);
      
      print('=== VOTING ON ${ocrResults.length} RESULTS ===');
      
      // Use voting to determine the best results
      final votedResults = _voteOnResults(ocrResults);
      
      setState(() {
        city = votedResults['city'] ?? 'Not found';
        date = votedResults['date'] ?? 'Not found';
        ticketNumber = votedResults['ticketNumber'] ?? 'Not found';
        rawText = votedResults['rawText'] ?? '';
        _processedImagePath = votedResults['imagePath'] ?? '';
        isProcessing = false;
        // Close camera after taking photos
        _isCameraInitialized = false;
      });
      
      // Dispose of camera controller
      _cameraController?.dispose();
      _cameraController = null;
      
    } catch (e) {
      print('Error in multi-shot process: $e');
      setState(() {
        rawText = 'Error: $e';
        isProcessing = false;
      });
    }
  }
  
  Future<Map<String, dynamic>?> _processSingleImage(XFile picture) async {
    try {
      // Load and process the image for lottery ticket OCR
      final originalBytes = await picture.readAsBytes();
      final originalImage = img.decodeImage(originalBytes);
      
      if (originalImage != null) {
        // Calculate crop area based on overlay frame (portrait orientation)
        final imageWidth = originalImage.width;
        final imageHeight = originalImage.height;
        
        final frameHeight = (imageHeight * 0.7).round();
        final frameWidth = (frameHeight * 0.6).round();
        final cropLeft = ((imageWidth - frameWidth) / 2).round();
        final cropTop = ((imageHeight - frameHeight) / 2).round();
        
        // Crop to the lottery ticket frame area
        final croppedImage = img.copyCrop(
          originalImage, 
          x: cropLeft, 
          y: cropTop, 
          width: frameWidth, 
          height: frameHeight
        );
        
        // For portrait mode, rotate 270 degrees to get correct orientation for OCR
        final rotatedImage = img.copyRotate(croppedImage, angle: 270);
        
        // Save rotated image to temporary file with high quality
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final tempFile = File('${tempDir.path}/lottery_${timestamp}.jpg');
        await tempFile.writeAsBytes(img.encodeJpg(rotatedImage, quality: 95));
        
        // Process with ML Kit
        final inputImage = InputImage.fromFilePath(tempFile.path);
        final recognizedText = await _textRecognizer.processImage(inputImage);

        // Extract all text
        String allText = '';
        for (TextBlock block in recognizedText.blocks) {
          for (TextLine line in block.lines) {
            allText += '${line.text}\n';
          }
        }

        // Parse the lottery ticket info for this image
        final parsedInfo = _parseTicketInfoForVoting(allText);
        
        return {
          'city': parsedInfo['city'],
          'date': parsedInfo['date'],
          'ticketNumber': parsedInfo['ticketNumber'],
          'rawText': allText,
          'imagePath': tempFile.path,
          'confidence': _calculateConfidence(parsedInfo)
        };
      }
    } catch (e) {
      print('Error processing single image: $e');
    }
    return null;
  }
  
  Map<String, dynamic> _voteOnResults(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      return {
        'city': 'Not found',
        'date': 'Not found', 
        'ticketNumber': 'Not found',
        'rawText': 'No valid OCR results',
        'imagePath': ''
      };
    }
    
    // Vote on each field independently
    final cityVotes = <String, int>{};
    final dateVotes = <String, int>{};
    final ticketVotes = <String, int>{};
    
    String bestImagePath = results[0]['imagePath'] ?? '';
    double bestOverallConfidence = 0.0;
    String combinedRawText = '';
    
    for (final result in results) {
      final city = result['city'] ?? 'Not found';
      final date = result['date'] ?? 'Not found';
      final ticket = result['ticketNumber'] ?? 'Not found';
      final confidence = result['confidence'] ?? 0.0;
      
      cityVotes[city] = (cityVotes[city] ?? 0) + 1;
      dateVotes[date] = (dateVotes[date] ?? 0) + 1;
      ticketVotes[ticket] = (ticketVotes[ticket] ?? 0) + 1;
      
      combinedRawText += '${result['rawText'] ?? ''}\n---\n';
      
      // Use the image with highest confidence
      if (confidence > bestOverallConfidence) {
        bestOverallConfidence = confidence;
        bestImagePath = result['imagePath'] ?? '';
      }
    }
    
    // Get the most voted results
    final bestCity = _getMostVoted(cityVotes);
    final bestDate = _getMostVoted(dateVotes);
    final bestTicket = _getMostVoted(ticketVotes);
    
    print('VOTING RESULTS:');
    print('City: $bestCity (from $cityVotes)');
    print('Date: $bestDate (from $dateVotes)');
    print('Ticket: $bestTicket (from $ticketVotes)');
    
    return {
      'city': bestCity,
      'date': bestDate,
      'ticketNumber': bestTicket,
      'rawText': combinedRawText,
      'imagePath': bestImagePath
    };
  }
  
  String _getMostVoted(Map<String, int> votes) {
    if (votes.isEmpty) return 'Not found';
    
    // Exclude 'Not found' if there are other options
    final validVotes = Map<String, int>.from(votes);
    if (validVotes.length > 1) {
      validVotes.remove('Not found');
    }
    
    return validVotes.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
  
  double _calculateConfidence(Map<String, dynamic> parsedInfo) {
    double confidence = 0.0;
    
    // Higher confidence for finding more fields
    if (parsedInfo['city'] != 'Not found') confidence += 0.4;
    if (parsedInfo['date'] != 'Not found') confidence += 0.3;
    if (parsedInfo['ticketNumber'] != 'Not found') confidence += 0.3;
    
    return confidence;
  }

  Map<String, dynamic> _parseTicketInfoForVoting(String text) {
    // Parse and return results for voting system
    final results = _parseTicketInfoInternal(text);
    return {
      'city': results['city'] ?? 'Not found',
      'date': results['date'] ?? 'Not found',
      'ticketNumber': results['ticketNumber'] ?? 'Not found'
    };
  }

  void _parseTicketInfo(String text) {
    final results = _parseTicketInfoInternal(text);
    city = results['city'] ?? 'Not found';
    date = results['date'] ?? 'Not found';
    ticketNumber = results['ticketNumber'] ?? 'Not found';
  }
  
  Map<String, dynamic> _parseTicketInfoInternal(String text) {
    String foundCity = 'Not found';
    String foundDate = 'Not found';
    String foundTicketNumber = 'Not found';
    
    // Use JSON-based city matching with enhanced OCR variations
    foundCity = _findCityFromJson(text);
    
    // Extract date using various patterns
    final datePatterns = [
      RegExp(r'(\d{1,2}[-/]\d{1,2}[-/]\d{4})'), // DD-MM-YYYY or DD/MM/YYYY
      RegExp(r'(\d{4}[-/]\d{1,2}[-/]\d{1,2})'), // YYYY-MM-DD or YYYY/MM/DD
      RegExp(r'(\d{1,2}\s*-\s*\d{1,2}\s*-\s*\d{4})'), // DD - MM - YYYY with spaces
      RegExp(r'Mở ngày\s*(\d{1,2}[-/]\d{1,2}[-/]\d{4})'), // "Mở ngày DD-MM-YYYY"
    ];
    
    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        foundDate = match.group(1) ?? 'Not found';
        break;
      }
    }
    
    // Extract ticket number - look for 6-digit numbers
    final ticketPatterns = [
      RegExp(r'\b(\d{6})\b'), // 6-digit number
      RegExp(r'(\d{6})\s*[A-Z]'), // 6 digits followed by letter
    ];
    
    for (final pattern in ticketPatterns) {
      final matches = pattern.allMatches(text);
      if (matches.isNotEmpty) {
        foundTicketNumber = matches.first.group(1) ?? 'Not found';
        break;
      }
    }
    
    return {
      'city': foundCity,
      'date': foundDate,
      'ticketNumber': foundTicketNumber
    };
  }
  
  String _findCityFromJson(String text) {
    if (_allCities.isEmpty) {
      return 'Not found'; // Cities not loaded yet
    }
    
    final upperText = text.toUpperCase();
    
    // Create enhanced mappings with OCR variations for cities from JSON
    final cityVariations = <String, List<String>>{
      'TP. Hồ Chí Minh': ['HO CHI MINH', 'HÓ CHÍ MINH', 'TP HCM', 'TP.HCM', 'TPHCM', 'SAI GON', 'SAIGON', 'CHI MINH', 'CHI MINT', 'CHỈ MINT', 'CHI MIN', 'HỐ CHÍ MIN', 'Ó CHI MINH', 'O CHI MINH'],
      'Hà Nội': ['HANOI', 'HÀ NỘI', 'HA NOI'],
      'Đà Nẵng': ['DANANG', 'ĐÀ NẴNG', 'DA NANG'],
      'Cần Thơ': ['CAN THO', 'CẦN THƠ'],
      'Hải Phòng': ['HAI PHONG', 'HẢI PHÒNG'],
      'An Giang': ['AN GIANG'],
      'Bạc Liêu': ['BAC LIEU', 'BẠC LIÊU'],
      'Bến Tre': ['BEN TRE', 'BẾN TRE'],
      'Bình Dương': ['BINH DUONG', 'BÌNH DƯƠNG', 'BÌNH DƯƠNGE', 'BINH DUONE', 'BÌNH DUONE'],
      'Bình Phước': ['BINH PHUOC', 'BÌNH PHƯỚC'],
      'Bình Thuận': ['BINH THUAN', 'BÌNH THUẬN'],
      'Cà Mau': ['CA MAU', 'CÀ MAU'],
      'Đồng Nai': ['DONG NAI', 'ĐỒNG NAI'],
      'Đồng Tháp': ['DONG THAP', 'ĐỒNG THÁP'],
      'Hậu Giang': ['HAU GIANG', 'HẬU GIANG'],
      'Kiên Giang': ['KIEN GIANG', 'KIÊN GIANG'],
      'Lâm Đồng': ['LAM DONG', 'LÂM ĐỒNG'],
      'Long An': ['LONG AN'],
      'Sóc Trăng': ['SOC TRANG', 'SÓC TRĂNG'],
      'Tây Ninh': ['TAY NINH', 'TÂY NINH'],
      'Tiền Giang': ['TIEN GIANG', 'TIỀN GIANG', 'TIÊN GIANG', 'TIEN CIANG'], // OCR variations for better matching
      'Trà Vinh': ['TRA VINH', 'TRÀ VINH'],
      'Vĩnh Long': ['VINH LONG', 'VĨNH LONG'],
      'Vũng Tàu': ['VUNG TAU', 'VŨNG TÀU'],
      'Bắc Ninh': ['BAC NINH', 'BẮC NINH'],
      'Nam Định': ['NAM DINH', 'NAM ĐỊNH'],
      'Quảng Ninh': ['QUANG NINH', 'QUẢNG NINH'],
      'Thái Bình': ['THAI BINH', 'THÁI BÌNH'],
      'Hà Nam': ['HA NAM', 'HÀ NAM'],
      'Hưng Yên': ['HUNG YEN', 'HƯNG YÊN'],
      'Vĩnh Phúc': ['VINH PHUC', 'VĨNH PHÚC'],
      'Ninh Bình': ['NINH BINH', 'NINH BÌNH'],
      'Bình Định': ['BINH DINH', 'BÌNH ĐỊNH'],
      'Đắk Lắk': ['DAK LAK', 'ĐẮK LẮK'],
      'Đắk Nông': ['DAK NONG', 'ĐẮK NÔNG'],
      'Gia Lai': ['GIA LAI'],
      'Kon Tum': ['KON TUM'],
      'Nghệ An': ['NGHE AN', 'NGHỆ AN'],
      'Hà Tĩnh': ['HA TINH', 'HÀ TĨNH'],
      'Quảng Trị': ['QUANG TRI', 'QUẢNG TRỊ'],
      'Quảng Bình': ['QUANG BINH', 'QUẢNG BÌNH'],
      'Thừa Thiên Huế': ['THUA THIEN HUE', 'THỪA THIÊN HUẾ', 'HUE', 'HUẾ'],
      'Khánh Hòa': ['KHANH HOA', 'KHÁNH HÒA'],
      'Phú Yên': ['PHU YEN', 'PHÚ YÊN'],
      'Quảng Nam': ['QUANG NAM', 'QUẢNG NAM'],
      'Quảng Ngãi': ['QUANG NGAI', 'QUẢNG NGÃI'],
    };

    // First try exact matching with variations
    for (final entry in cityVariations.entries) {
      final cityName = entry.key;
      final variations = entry.value;
      
      for (final variation in variations) {
        if (upperText.contains(variation)) {
          print('Found exact match: $cityName for variation: $variation');
          return cityName;
        }
      }
    }
    
    // Special aggressive matching for Ho Chi Minh City variants
    if (upperText.contains('CHI MIN') || 
        upperText.contains('CHI MINH') || 
        upperText.contains('CHI MINT') ||
        upperText.contains('HO CHI') ||
        upperText.contains('TPHCM') ||
        (upperText.contains('CHI') && upperText.contains('MIN'))) {
      print('Special Ho Chi Minh matching found');
      return 'TP. Hồ Chí Minh';
    }
    
    // If no exact match, try fuzzy matching with all JSON cities
    double bestScore = 0.0;
    String bestMatch = 'Not found';
    
    for (final cityName in _allCities) {
      final normalizedCity = _normalizeForOCR(cityName);
      final normalizedText = _normalizeForOCR(upperText);
      
      final score = _calculateSimilarity(normalizedText, normalizedCity);
      if (score > bestScore && score > 0.6) { // 60% threshold for matching
        bestScore = score;
        bestMatch = cityName;
      }
      
      // Also check variations if they exist
      if (cityVariations.containsKey(cityName)) {
        for (final variation in cityVariations[cityName]!) {
          final score = _calculateSimilarity(upperText, variation);
          if (score > bestScore && score > 0.6) {
            bestScore = score;
            bestMatch = cityName;
          }
        }
      }
    }
    
    if (bestMatch != 'Not found') {
      print('Fuzzy matched city: $bestMatch (score: ${bestScore.toStringAsFixed(2)})');
      return bestMatch;
    }
    
    return 'Not found';
  }

  // Check if any critical values are missing
  bool _hasMissingValues() {
    return city == 'Not found' || date == 'Not found' || ticketNumber == 'Not found';
  }

  // Start a new photo session and open camera directly
  Future<void> _scanAnother() async {
    setState(() {
      _capturedImagePath = null;
      _processedImagePath = null;
      city = 'Not found';
      date = 'Not found';
      ticketNumber = 'Not found';
      rawText = '';
      _isCameraInitialized = false;
    });
    
    // Directly open camera
    await _initializeCamera();
  }

  // Calculate similarity between two strings with OCR error tolerance
  double _calculateSimilarity(String text, String pattern) {
    // Normalize both strings to handle OCR errors
    final normalizedText = _normalizeForOCR(text);
    final normalizedPattern = _normalizeForOCR(pattern);
    
    // Direct match
    if (normalizedText.contains(normalizedPattern)) return 1.0;
    
    // Check each word in the text against the pattern
    final words = normalizedText.split(RegExp(r'\s+'));
    double bestScore = 0.0;
    
    for (final word in words) {
      if (word.isEmpty) continue;
      
      // Check if pattern is contained in word or vice versa
      if (word.contains(normalizedPattern) || normalizedPattern.contains(word)) {
        final longer = word.length > normalizedPattern.length ? word : normalizedPattern;
        final shorter = word.length > normalizedPattern.length ? normalizedPattern : word;
        final score = shorter.length / longer.length;
        if (score > bestScore) bestScore = score;
      }
      
      // Character-by-character similarity with tolerance for OCR errors
      final charScore = _characterSimilarity(word, normalizedPattern);
      if (charScore > bestScore) bestScore = charScore;
    }
    
    return bestScore;
  }
  
  // Normalize text for OCR error handling
  String _normalizeForOCR(String text) {
    return text
        .toUpperCase()
        .replaceAll('0', 'O')      // Common OCR error: 0 -> O
        .replaceAll('1', 'I')      // Common OCR error: 1 -> I
        .replaceAll('5', 'S')      // Common OCR error: 5 -> S
        .replaceAll('8', 'B')      // Common OCR error: 8 -> B
        .replaceAll('6', 'G')      // Common OCR error: 6 -> G
        .replaceAll('Ơ', 'O')      // Vietnamese accent variations
        .replaceAll('Ư', 'U')      // Vietnamese accent variations
        .replaceAll('Đ', 'D')      // Vietnamese accent variations
        .replaceAll('À', 'A')      // Vietnamese accent variations
        .replaceAll('Ả', 'A')      // Vietnamese accent variations
        .replaceAll('Ã', 'A')      // Vietnamese accent variations
        .replaceAll('Á', 'A')      // Vietnamese accent variations
        .replaceAll('Ạ', 'A')      // Vietnamese accent variations
        .replaceAll('Ă', 'A')      // Vietnamese accent variations
        .replaceAll('Ằ', 'A')      // Vietnamese accent variations
        .replaceAll('Ẳ', 'A')      // Vietnamese accent variations
        .replaceAll('Ẵ', 'A')      // Vietnamese accent variations
        .replaceAll('Ắ', 'A')      // Vietnamese accent variations
        .replaceAll('Ặ', 'A')      // Vietnamese accent variations
        .replaceAll('Â', 'A')      // Vietnamese accent variations
        .replaceAll('Ầ', 'A')      // Vietnamese accent variations
        .replaceAll('Ẩ', 'A')      // Vietnamese accent variations
        .replaceAll('Ẫ', 'A')      // Vietnamese accent variations
        .replaceAll('Ấ', 'A')      // Vietnamese accent variations
        .replaceAll('Ậ', 'A')      // Vietnamese accent variations
        .replaceAll('È', 'E')      // Vietnamese accent variations
        .replaceAll('Ẻ', 'E')      // Vietnamese accent variations
        .replaceAll('Ẽ', 'E')      // Vietnamese accent variations
        .replaceAll('É', 'E')      // Vietnamese accent variations
        .replaceAll('Ẹ', 'E')      // Vietnamese accent variations
        .replaceAll('Ê', 'E')      // Vietnamese accent variations
        .replaceAll('Ề', 'E')      // Vietnamese accent variations
        .replaceAll('Ể', 'E')      // Vietnamese accent variations
        .replaceAll('Ễ', 'E')      // Vietnamese accent variations
        .replaceAll('Ế', 'E')      // Vietnamese accent variations
        .replaceAll('Ệ', 'E')      // Vietnamese accent variations
        .replaceAll('Ì', 'I')      // Vietnamese accent variations
        .replaceAll('Ỉ', 'I')      // Vietnamese accent variations
        .replaceAll('Ĩ', 'I')      // Vietnamese accent variations
        .replaceAll('Í', 'I')      // Vietnamese accent variations
        .replaceAll('Ị', 'I')      // Vietnamese accent variations
        .replaceAll('Ò', 'O')      // Vietnamese accent variations
        .replaceAll('Ỏ', 'O')      // Vietnamese accent variations
        .replaceAll('Õ', 'O')      // Vietnamese accent variations
        .replaceAll('Ó', 'O')      // Vietnamese accent variations
        .replaceAll('Ọ', 'O')      // Vietnamese accent variations
        .replaceAll('Ô', 'O')      // Vietnamese accent variations
        .replaceAll('Ồ', 'O')      // Vietnamese accent variations
        .replaceAll('Ổ', 'O')      // Vietnamese accent variations
        .replaceAll('Ỗ', 'O')      // Vietnamese accent variations
        .replaceAll('Ố', 'O')      // Vietnamese accent variations
        .replaceAll('Ộ', 'O')      // Vietnamese accent variations
        .replaceAll('Ờ', 'O')      // Vietnamese accent variations
        .replaceAll('Ở', 'O')      // Vietnamese accent variations
        .replaceAll('Ỡ', 'O')      // Vietnamese accent variations
        .replaceAll('Ớ', 'O')      // Vietnamese accent variations
        .replaceAll('Ợ', 'O')      // Vietnamese accent variations
        .replaceAll('Ù', 'U')      // Vietnamese accent variations
        .replaceAll('Ủ', 'U')      // Vietnamese accent variations
        .replaceAll('Ũ', 'U')      // Vietnamese accent variations
        .replaceAll('Ú', 'U')      // Vietnamese accent variations
        .replaceAll('Ụ', 'U')      // Vietnamese accent variations
        .replaceAll('Ứ', 'U')      // Vietnamese accent variations
        .replaceAll('Ừ', 'U')      // Vietnamese accent variations
        .replaceAll('Ử', 'U')      // Vietnamese accent variations
        .replaceAll('Ữ', 'U')      // Vietnamese accent variations
        .replaceAll('Ự', 'U')      // Vietnamese accent variations
        .replaceAll('Ỳ', 'Y')      // Vietnamese accent variations
        .replaceAll('Ỷ', 'Y')      // Vietnamese accent variations
        .replaceAll('Ỹ', 'Y')      // Vietnamese accent variations
        .replaceAll('Ý', 'Y')      // Vietnamese accent variations
        .replaceAll('Ỵ', 'Y')      // Vietnamese accent variations
        .replaceAll(RegExp(r'[^\w\s]'), ' ')  // Remove special characters
        .replaceAll(RegExp(r'\s+'), ' ')      // Normalize whitespace
        .trim();
  }
  
  // Character-by-character similarity with OCR tolerance
  double _characterSimilarity(String word1, String word2) {
    if (word1.isEmpty || word2.isEmpty) return 0.0;
    
    final shorter = word1.length < word2.length ? word1 : word2;
    final longer = word1.length < word2.length ? word2 : word1;
    
    int matches = 0;
    int i = 0, j = 0;
    
    while (i < shorter.length && j < longer.length) {
      if (shorter[i] == longer[j]) {
        matches++;
        i++;
        j++;
      } else {
        // Try skipping a character in the longer string (OCR insertion error)
        if (j < longer.length - 1 && shorter[i] == longer[j + 1]) {
          matches++;
          i++;
          j += 2;
        } else {
          i++;
          j++;
        }
      }
    }
    
    return matches / longer.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vietnamese Lottery OCR'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Processed image with adaptive height
            if (_processedImagePath != null) ...[
              // Show processed (cropped & rotated) image that was actually analyzed
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        color: Colors.green,
                        width: double.infinity,
                        child: Text(
                          'Processed Image (Cropped & Rotated for OCR)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Image with natural aspect ratio
                      Image.file(
                        File(_processedImagePath!),
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_isCameraInitialized && _cameraController != null) ...[
              // Full screen camera view
              Container(
                height: 600, // Full screen-like view
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Full camera preview with tap to focus
                      GestureDetector(
                        onTapUp: (TapUpDetails details) async {
                          // Calculate tap position relative to camera preview
                          final renderBox = context.findRenderObject() as RenderBox;
                          final tapPosition = renderBox.globalToLocal(details.globalPosition);
                          final previewSize = renderBox.size;
                          
                          // Convert tap position to camera coordinates (0.0 to 1.0)
                          final x = tapPosition.dx / previewSize.width;
                          final y = tapPosition.dy / previewSize.height;
                          
                          try {
                            await _cameraController!.setFocusPoint(Offset(x, y));
                            await _cameraController!.setExposurePoint(Offset(x, y));
                          } catch (e) {
                            print('Focus/exposure setting failed: $e');
                          }
                        },
                        child: CameraPreview(_cameraController!),
                      ),
                      
                      // Lottery ticket overlay frame (no text)
                      Container(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: LotteryTicketOverlayPainter(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              
              // Take picture button
              Center(
                child: ElevatedButton(
                  onPressed: isProcessing ? null : _takePictureAndProcess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isProcessing ? 'Processing...' : 'Take Picture',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ] else ...[
              // Start camera button when camera not initialized
              Container(
                height: 600, // Match the camera preview height
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 64, color: Colors.grey[600]),
                      SizedBox(height: 16),
                      Text(
                        'Portrait Camera Mode\n(Optimized for Lottery Tickets)',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: isProcessing ? null : _initializeCamera,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isProcessing ? 'Starting Camera...' : 'Start Camera',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            SizedBox(height: 20),
            
            // Action buttons when image is captured
            if (_processedImagePath != null) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _scanAnother,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Scan Another'),
                    ),
                  ),
                  if (_hasMissingValues()) ...[
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isProcessing ? null : () async {
                          if (_processedImagePath != null) {
                            setState(() {
                              isProcessing = true;
                            });
                            
                            // Reprocess the same processed image with OCR
                            final inputImage = InputImage.fromFilePath(_processedImagePath!);
                            final recognizedText = await _textRecognizer.processImage(inputImage);

                            String allText = '';
                            for (TextBlock block in recognizedText.blocks) {
                              for (TextLine line in block.lines) {
                                allText += '${line.text}\n';
                              }
                            }

                            print('=== RESCAN OCR TEXT ===');
                            print(allText);
                            print('========================');

                            _parseTicketInfo(allText);

                            setState(() {
                              rawText = allText;
                              isProcessing = false;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(isProcessing ? 'Rescanning...' : 'Rescan'),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 20),
            ],
            
            Text(
              'CURRENT RESULTS:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            
            if (isProcessing) ...[
              Center(child: CircularProgressIndicator()),
              SizedBox(height: 10),
              Text('Processing image with OCR...', textAlign: TextAlign.center),
            ] else ...[
              _buildResultRow('City:', city),
              _buildResultRow('Date:', date),
              _buildResultRow('Ticket Number:', ticketNumber),
              
              SizedBox(height: 20),
              
              if (rawText.isNotEmpty) ...[
                Text(
                  'RAW OCR TEXT:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 200, // Fixed height instead of Expanded
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      rawText,
                      style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  height: 200, // Fixed height instead of Expanded
                  child: Center(
                    child: Text(
                      'Take a picture to extract lottery ticket information\n\nThe app will automatically:\n1. Rotate the image 270°\n2. Run OCR\n3. Extract City, Date, and Ticket Number',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
              
              // Add some bottom padding so content isn't cut off
              SizedBox(height: 50),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String actual) {
    final isFound = actual != 'Not found';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 8),
          Text(
            actual,
            style: TextStyle(
              color: isFound ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8),
          Icon(
            isFound ? Icons.check_circle : Icons.error,
            color: isFound ? Colors.green : Colors.red,
            size: 20,
          ),
        ],
      ),
    );
  }
}