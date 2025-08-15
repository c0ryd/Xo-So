import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../services/ticket_storage_service.dart';
import '../services/image_storage_service.dart';
import '../services/ad_service.dart';
import '../widgets/vietnamese_tiled_background.dart';
import '../main.dart'; // For cameras list
import 'scan_results_screen.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';
import 'package:http/http.dart' as http;

// Copy the LotteryTicketOverlayPainter from main.dart
class LotteryTicketOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Calculate lottery ticket frame dimensions (portrait orientation)
    final frameWidth = size.width * 0.7;  // 70% of screen width
    final frameHeight = frameWidth * 1.6; // Portrait aspect ratio - taller than wide
    final left = (size.width - frameWidth) / 2;
    final top = (size.height - frameHeight) / 2;

    // Draw the main frame
    final rect = Rect.fromLTWH(left, top, frameWidth, frameHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(8)),
      paint,
    );

    // Draw corner markers for better visibility
    final cornerLength = 20.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

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

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
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
  Map<String, List<String>> _provinceSchedule = {};
  
  // Winner checking state
  bool _isCheckingWinner = false;
  bool? _isWinner;
  int? _winAmount;
  List<String>? _matchedTiers;
  String? _winnerCheckError;
  int _ticketQuantity = 1;
  String? _storedTicketId; // Track the stored ticket ID for duplication
  
  // Auto-scanning state
  bool _isAutoScanning = false;
  int _autoScanAttempts = 0;
  static const int _maxAutoScanAttempts = 20; // Stop after 20 attempts
  Timer? _autoScanTimer;
  
  // Banner ad state
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  
  // View state to track if we're showing results
  bool _showingResults = false;

  @override
  void initState() {
    super.initState();
    _loadCitiesData();
    _loadProvinceSchedule();
    _createBannerAd(); // Create ad early for faster loading
    
    // Initialize camera automatically when screen loads
    _initializeCamera();
  }

  @override
  void dispose() {
    _autoScanTimer?.cancel();
    _cameraController?.dispose();
    _textRecognizer.close();
    _disposeBannerAd();
    super.dispose();
  }

  // TODO: Copy all the working camera methods from LotteryOCRScreen in main.dart
  // For now, this is a placeholder structure

  Future<void> _initializeCamera() async {
    if (cameras.isNotEmpty) {
      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      
      try {
        await _cameraController!.initialize();
        
        // Lock camera orientation to portrait
        await _cameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);
        
        // Set focus mode for better image quality
        await _cameraController!.setFocusMode(FocusMode.auto);
        
        setState(() {
          _isCameraInitialized = true;
        });
        
        // Start auto-scanning automatically after a short delay
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) {
            _startAutoScanning();
          }
        });
      } catch (e) {
        print('Error initializing camera: $e');
      }
    }
  }

  void _startAutoScanning() {
    if (_isAutoScanning) return; // Already running
    
    setState(() {
      _isAutoScanning = true;
      _autoScanAttempts = 0;
      // Reset field detection state
      city = 'Not found';
      date = 'Not found';
      ticketNumber = 'Not found';
      rawText = '';
      // Reset winner checking state
      _isCheckingWinner = false;
      _isWinner = null;
      _winAmount = null;
      _matchedTiers = null;
      _winnerCheckError = null;
      _ticketQuantity = 1;
    });
    
    // Create banner ad when scanning starts
    _createBannerAd();
    
    print('=== AUTO-SCANNING STARTED ===');
    _performAutoScan();
  }

  void _stopAutoScanning() {
    _autoScanTimer?.cancel();
    setState(() {
      _isAutoScanning = false;
    });
    
    // Dispose banner ad when scanning stops
    _disposeBannerAd();
    
    print('=== AUTO-SCANNING STOPPED ===');
  }

  Future<void> _performAutoScan() async {
    if (!_isAutoScanning || _autoScanAttempts >= _maxAutoScanAttempts) {
      print('Auto-scan stopping: isAutoScanning=$_isAutoScanning, attempts=$_autoScanAttempts');
      _stopAutoScanning();
      return;
    }
    
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('Auto-scan stopping: camera not initialized');
      _stopAutoScanning();
      return;
    }
    
    setState(() {
      _autoScanAttempts++;
    });
    print('Auto-scan attempt ${_autoScanAttempts}/${_maxAutoScanAttempts}');
    
    try {
      // Take 3 pictures with different exposure compensations for better OCR accuracy
      final List<Map<String, dynamic>> ocrResults = [];
      final exposureOffsets = [-1.0, 0.0, 1.0];
      for (int i = 0; i < 3; i++) {
        // Check if camera is still valid before each shot
        if (_cameraController == null || !_cameraController!.value.isInitialized || !mounted) {
          print('Auto-scan shot ${i + 1} cancelled: camera not available');
          break;
        }
        
        try {
          await _cameraController!.setExposureOffset(exposureOffsets[i]);
          await Future.delayed(Duration(milliseconds: 200));
          
          // Double-check before taking picture
          if (_cameraController == null || !_cameraController!.value.isInitialized || !mounted) {
            print('Auto-scan shot ${i + 1} cancelled before takePicture: camera not available');
            break;
          }
          
          final XFile picture = await _cameraController!.takePicture();
          final processedResult = await _processSingleImage(picture);
          if (processedResult != null) {
            ocrResults.add(processedResult);
          }
        } catch (e) {
          print('Auto-scan shot ${i + 1} error: $e');
          // If camera errors occur, stop the multi-shot process
          if (e.toString().contains('disposed') || e.toString().contains('Disposed')) {
            print('Camera disposed during multi-shot, stopping auto-scan');
            _stopAutoScanning();
            return;
          }
        }
      }
      
      // Reset exposure to normal (with safety check)
      try {
        if (_cameraController != null && _cameraController!.value.isInitialized && mounted) {
          await _cameraController!.setExposureOffset(0.0);
        }
      } catch (e) {
        print('Error resetting exposure: $e');
      }

      // Vote on the results
      final voted = _voteOnResults(ocrResults);
      final cityResult = voted['city'] as String;
      final dateResult = voted['date'] as String;
      final ticketResult = voted['ticketNumber'] as String;
      final hasGoodCity = cityResult != 'Not found';
      final hasGoodDate = dateResult != 'Not found';
      final hasGoodTicket = ticketResult != 'Not found';
      final foundCount = (hasGoodCity ? 1 : 0) + (hasGoodDate ? 1 : 0) + (hasGoodTicket ? 1 : 0);

      print('Auto-scan voted - City: $cityResult, Date: $dateResult, Ticket: $ticketResult');
      print('Found: ${foundCount}/3 fields (need all 3 to stop)');

      if (foundCount == 3) {
        print('=== AUTO-SCAN SUCCESS (VOTED)! Found $foundCount/3 fields ===');
        _stopAutoScanning();
        setState(() {
          city = cityResult;
          date = dateResult;
          ticketNumber = ticketResult;
          rawText = voted['rawText'] ?? '';
          isProcessing = false;
          _isCameraInitialized = false;
          // Show results overlay immediately - keep camera alive
          _showingResults = true;
          _processedImagePath = voted['imagePath'];
        });

        // Start background processing (save image, store in DB, check winner) - don't await
        _performBackgroundProcessing(voted, cityResult, dateResult, ticketResult);
        return;
      }

      // Schedule next scan faster
      if (_isAutoScanning && _autoScanAttempts < _maxAutoScanAttempts) {
        print('Scheduling next auto-scan in 500 ms...');
        _autoScanTimer = Timer(Duration(milliseconds: 500), () {
          _performAutoScan();
        });
      } else {
        print('Auto-scan stopped: attempts=${_autoScanAttempts}, maxAttempts=${_maxAutoScanAttempts}');
        _stopAutoScanning();
      }

    } catch (e) {
      print('Error in auto-scan: $e');
      _stopAutoScanning();
    }
  }

  // Process a single captured image: crop to frame, find best rotation, run OCR, parse fields
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
          height: frameHeight,
        );
        
        // Dynamically determine the best rotation (90° or 270°) for OCR
        final bestRotationResult = await _findBestRotation(croppedImage);
        final rotatedImage = bestRotationResult['image'] as img.Image;
        final rotationAngle = bestRotationResult['angle'] as int; // not used further, for logs
        final recognizedText = bestRotationResult['text'] as RecognizedText;
        
        print('🔄 Best rotation determined: ${rotationAngle}°');
        
        // Save the best rotated image to temporary file with high quality
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final tempFile = File('${tempDir.path}/lottery_${timestamp}.jpg');
        await tempFile.writeAsBytes(img.encodeJpg(rotatedImage, quality: 95));
        
        // Extract all text
        String allText = '';
        print('🔍 OCR EXTRACTION: Found ${recognizedText.blocks.length} text blocks');
        for (TextBlock block in recognizedText.blocks) {
          print('🔍 Block text: "${block.text}"');
          for (TextLine line in block.lines) {
            print('🔍 Line text: "${line.text}"');
            allText += '${line.text}\n';
          }
        }
        print('🔍 FINAL OCR TEXT LENGTH: ${allText.length}');
        if (allText.length > 0) {
          print('🔍 OCR TEXT PREVIEW: ${allText.substring(0, math.min(100, allText.length))}');
        }
        
        // Parse the lottery ticket info for this image
        final parsedInfo = _parseTicketInfoForVoting(allText);
        
        return {
          'city': parsedInfo['city'],
          'date': parsedInfo['date'],
          'ticketNumber': parsedInfo['ticketNumber'],
          'rawText': allText,
          'imagePath': tempFile.path,
          'confidence': _calculateConfidence(parsedInfo),
        };
      }
    } catch (e) {
      print('Error processing single image: $e');
    }
    return null;
  }

  // Data loading methods
  Future<void> _loadCitiesData() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/cities.json');
      _citiesData = json.decode(jsonString);
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

  // Derived UI helpers to match original behavior
  bool _hasMissingValues() {
    return city == 'Not found' || date == 'Not found' || ticketNumber == 'Not found';
  }

  String _getFoundFieldsText() {
    int foundCount = 0;
    if (city != 'Not found') foundCount++;
    if (date != 'Not found') foundCount++;
    if (ticketNumber != 'Not found') foundCount++;
    return '$foundCount/3';
  }

  Future<void> _loadProvinceSchedule() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/province_schedule.json');
      final Map<String, dynamic> scheduleData = json.decode(jsonString);
      _provinceSchedule.clear();
      scheduleData.forEach((province, days) {
        _provinceSchedule[province] = (days as List).cast<String>();
      });
      print('Loaded province schedule for ${_provinceSchedule.length} provinces');
    } catch (e) {
      print('Error loading province schedule: $e');
    }
  }

  // Ad methods
  void _createBannerAd() {
    _bannerAd = AdService.createBannerAd(
      onAdLoaded: (ad) {
        setState(() {
          _isBannerAdReady = true;
        });
        print('Banner ad loaded successfully');
      },
      onAdFailedToLoad: (ad, error) {
        print('Banner ad failed to load: $error');
        ad.dispose();
        setState(() {
          _bannerAd = null;
          _isBannerAdReady = false;
        });
      },
    );
    
    _bannerAd?.load();
  }
  
  void _disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    setState(() {
      _isBannerAdReady = false;
    });
  }

  // --- OCR helpers copied from working screen ---
  double _calculateConfidence(Map<String, dynamic> parsedInfo) {
    double confidence = 0.0;
    if (parsedInfo['city'] != 'Not found') confidence += 0.4;
    if (parsedInfo['date'] != 'Not found') confidence += 0.3;
    if (parsedInfo['ticketNumber'] != 'Not found') confidence += 0.3;
    return confidence;
  }
  
  Map<String, dynamic> _parseTicketInfoForVoting(String text) {
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
    
    // Extract date
    final datePatterns = [
      RegExp(r'(\d{1,2}[-/]\d{1,2}[-/]\d{4})'),
      RegExp(r'(\d{4}[-/]\d{1,2}[-/]\d{1,2})'),
      RegExp(r'(\d{1,2}\s*-\s*\d{1,2}\s*-\s*\d{4})'),
      RegExp(r'Mở ngày\s*(\d{1,2}[-/]\d{1,2}[-/]\d{4})'),
    ];
    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        foundDate = match.group(1) ?? 'Not found';
        break;
      }
    }
    
    // Extract ticket number
    final ticketPatterns = [
      RegExp(r'\b(\d{6})\b'),
      RegExp(r'(\d{6})\s*[A-Z]'),
    ];
    for (final pattern in ticketPatterns) {
      final matches = pattern.allMatches(text);
      if (matches.isNotEmpty) {
        foundTicketNumber = matches.first.group(1) ?? 'Not found';
        break;
      }
    }
    
    // Filter provinces by date
    List<String> validProvinces = _allCities;
    if (foundDate != 'Not found') {
      print('🔍 PARSING DEBUG: Found date "$foundDate", filtering provinces...');
      validProvinces = _getValidProvincesForDate(foundDate);
      print('📋 Filtered provinces count: ${validProvinces.length}');
      if (validProvinces.length <= 10) {
        print('📋 Filtered provinces: $validProvinces');
      }
    }
    
    // Detect city from OCR text
    print('🏙️ Searching for city in OCR text with ${validProvinces.length} valid provinces');
    foundCity = _findCityFromFilteredList(text, validProvinces);
    print('🏙️ Detected city: "$foundCity"');
    
    return {
      'city': foundCity,
      'date': foundDate,
      'ticketNumber': foundTicketNumber
    };
  }
  
  Future<Map<String, dynamic>> _findBestRotation(img.Image croppedImage) async {
    print('🔄 Testing rotations to find best OCR orientation...');
    final rotationResults = <Map<String, dynamic>>[];
    final tempDir = await getTemporaryDirectory();
    
    for (final angle in [90, 270]) {
      try {
        print('🔄 Testing ${angle}° rotation...');
        final rotatedImage = img.copyRotate(croppedImage, angle: angle);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final tempFile = File('${tempDir.path}/rotation_test_${angle}_${timestamp}.jpg');
        await tempFile.writeAsBytes(img.encodeJpg(rotatedImage, quality: 90));
        final inputImage = InputImage.fromFilePath(tempFile.path);
        final recognizedText = await _textRecognizer.processImage(inputImage);
        
        String allText = '';
        for (TextBlock block in recognizedText.blocks) {
          for (TextLine line in block.lines) {
            allText += line.text + '\n';
          }
        }
        
        final score = _scoreOcrResult(allText);
        print('🔄 ${angle}° rotation score: $score');
        print('🔄 ${angle}° text preview: ${allText.length > 50 ? allText.substring(0, 50) + "..." : allText}');
        
        rotationResults.add({
          'angle': angle,
          'image': rotatedImage,
          'text': recognizedText,
          'allText': allText,
          'score': score,
        });
        
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        print('🔄 Error testing ${angle}° rotation: $e');
        rotationResults.add({
          'angle': angle,
          'image': img.copyRotate(croppedImage, angle: angle),
          'text': null,
          'allText': '',
          'score': 0,
        });
      }
    }
    rotationResults.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    final bestResult = rotationResults.first;
    print('🔄 Best rotation: ${bestResult['angle']}° (score: ${bestResult['score']})');
    return bestResult;
  }
  
  double _scoreOcrResult(String text) {
    if (text.trim().isEmpty) return 0.0;
    double score = 0.0;
    final cleanText = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\s-]'), '');
    score += cleanText.length * 0.1;
    final numbers = RegExp(r'\d+').allMatches(cleanText);
    score += numbers.length * 2.0;
    final datePattern = RegExp(r'\d{1,2}[-/]\d{1,2}[-/]\d{4}');
    if (datePattern.hasMatch(cleanText)) {
      score += 15.0;
    }
    final foundProvince = _findCityFromFilteredList(cleanText, _allCities);
    if (foundProvince != 'Not found') {
      score += 20.0;
    }
    final lotteryKeywords = ['XO SO', 'XOSO', 'KIEN THIET', 'GIAI', 'DIEN TOAN', 'TIEN GIANG', 'LONG AN', 'CAN THO'];
    for (final keyword in lotteryKeywords) {
      if (cleanText.contains(keyword)) {
        score += 5.0;
      }
    }
    final ticketNumbers = RegExp(r'\b\d{5,6}\b').allMatches(cleanText);
    score += ticketNumbers.length * 10.0;
    final specialChars = text.length - cleanText.length;
    score -= specialChars * 0.5;
    return score;
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
      if (confidence > bestOverallConfidence) {
        bestOverallConfidence = confidence;
        bestImagePath = result['imagePath'] ?? '';
      }
    }
    final bestCity = _getMostVoted(cityVotes);
    final bestDate = _getMostVoted(dateVotes);
    final bestTicket = _getMostVoted(ticketVotes);
    return {
      'city': bestCity,
      'date': bestDate,
      'ticketNumber': bestTicket,
      'rawText': combinedRawText,
      'imagePath': bestImagePath,
    };
  }

  String _getMostVoted(Map<String, int> votes) {
    if (votes.isEmpty) return 'Not found';
    final validVotes = Map<String, int>.from(votes);
    if (validVotes.length > 1) {
      validVotes.remove('Not found');
    }
    return validVotes.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
  
  List<String> _getValidProvincesForDate(String dateText) {
    try {
      print('🔍 PROVINCE FILTER DEBUG: Parsing date "$dateText"');
      final parts = dateText.replaceAll('/', '-').split('-');
      if (parts.length != 3) {
        print('❌ Invalid date format, parts: $parts - returning all cities');
        return _allCities;
      }
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final parsedDate = DateTime(year, month, day);
      final dayOfWeek = _getDayOfWeek(parsedDate.weekday);
      print('📅 Parsed date: $parsedDate (Day of week: $dayOfWeek)');
      
      final valid = <String>[];
      _provinceSchedule.forEach((province, days) {
        if (days.contains(dayOfWeek)) {
          valid.add(province);
        }
      });
      
      print('✅ Valid provinces for $dayOfWeek: $valid');
      
      // TEMPORARY: Revert to debug the date parsing issue
      if (valid.isEmpty) {
        print('⚠️ No provinces draw on $dayOfWeek - falling back to all cities (TEMP DEBUG)');
        return _allCities;
      }
      
      return valid;
    } catch (e) {
      print('❌ Error parsing date "$dateText": $e - returning all cities');
      return _allCities;
    }
  }
  
  String _findCityFromFilteredList(String text, List<String> provinces) {
    if (provinces.isEmpty) return 'Not found';
    final upperText = text.toUpperCase();
    
    print('🔍 CITY DETECTION: Searching in ${provinces.length} provinces');
    if (upperText.length > 20) {
      print('🔍 OCR text preview: ${upperText.substring(0, math.min(200, upperText.length))}...');
    } else {
      print('🔍 OCR text preview: "$upperText" (SHORT/EMPTY)');
    }
    
    // SIMPLIFIED: Just use original logic for now
    String bestCity = 'Not found';
    double bestScore = 0.0;
    for (final province in provinces) {
      final normalizedProvince = _normalizeProvinceName(province).toUpperCase();
      final score = _calculateSimilarity(upperText, normalizedProvince);
      if (score > bestScore && score > 0.7) {
        bestScore = score;
        bestCity = province;
      }
    }
    
    if (bestCity != 'Not found') {
      print('✅ MATCH: Found "$bestCity" (score: $bestScore)');
    } else {
      print('❌ NO MATCH: No city found');
    }
    
    return bestCity;
  }
  
  String _normalizeForOCR(String text) {
    return text
        .toUpperCase()
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll('5', 'S')
        .replaceAll('8', 'B')
        .replaceAll('6', 'G')
        .replaceAll('Ơ', 'O')
        .replaceAll('Ư', 'U')
        .replaceAll('Đ', 'D')
        .replaceAll('À', 'A')
        .replaceAll('Ả', 'A')
        .replaceAll('Ã', 'A')
        .replaceAll('Á', 'A')
        .replaceAll('Ạ', 'A')
        .replaceAll('Ă', 'A');
  }
  
  double _calculateSimilarity(String text, String pattern) {
    final normalizedText = _normalizeForOCR(text);
    final normalizedPattern = _normalizeForOCR(pattern);
    if (normalizedText.contains(normalizedPattern)) return 1.0;
    final words = normalizedText.split(RegExp(r'\s+'));
    double bestScore = 0.0;
    for (final word in words) {
      if (word.isEmpty) continue;
      if (word.contains(normalizedPattern) || normalizedPattern.contains(word)) {
        final longer = word.length > normalizedPattern.length ? word : normalizedPattern;
        final shorter = word.length > normalizedPattern.length ? normalizedPattern : word;
        final score = shorter.length / longer.length;
        if (score > bestScore) bestScore = score;
      }
      final charScore = _characterSimilarity(word, normalizedPattern);
      if (charScore > bestScore) bestScore = charScore;
    }
    return bestScore;
  }
  
  double _characterSimilarity(String a, String b) {
    final lenA = a.length;
    final lenB = b.length;
    if (lenA == 0 || lenB == 0) return 0.0;
    int matches = 0;
    final minLen = lenA < lenB ? lenA : lenB;
    for (int i = 0; i < minLen; i++) {
      if (a[i] == b[i]) matches++;
    }
    return matches / (lenA > lenB ? lenA : lenB);
  }
  
  String _getDayOfWeek(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return 'Monday';
    }
  }
  
  String _normalizeProvinceName(String name) {
    return name
        .replaceAll('TP. ', '')
        .replaceAll('Thành phố ', '')
        .replaceAll('Tỉnh ', '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Let content go under AppBar
      backgroundColor: Colors.transparent, // Allow Vietnamese background to show through
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Transparent AppBar
        elevation: 0, // No shadow
        title: Text('Scan Ticket'),
        leading: (_isCameraInitialized) ? BackButton(
          onPressed: () {
            _stopAutoScanning();
            Navigator.pop(context);
          },
        ) : null,
        automaticallyImplyLeading: !_isCameraInitialized,
      ),
      body: VietnameseTiledBackground(
        child: Stack(
          children: [
            // Main camera UI
            SingleChildScrollView(
            padding: EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 16), // Extra top padding for transparent AppBar
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            if (_processedImagePath != null) ...[
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFFFE8BE), width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_processedImagePath!),
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              ),
              SizedBox(height: 8),
            ],

            if ((_isAutoScanning || _isCameraInitialized) && _isBannerAdReady && _bannerAd != null) ...[
              Container(
                alignment: Alignment.center,
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
              SizedBox(height: 16),
            ],

            if (_isCameraInitialized && _cameraController != null) ...[
              Container(
                height: 600,
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
                      GestureDetector(
                        onTapUp: (TapUpDetails details) async {
                          final renderBox = context.findRenderObject() as RenderBox;
                          final tapPosition = renderBox.globalToLocal(details.globalPosition);
                          final previewSize = renderBox.size;
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
                      CustomPaint(
                        size: Size.infinite,
                        painter: LotteryTicketOverlayPainter(),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              if (_isAutoScanning) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    border: Border.all(color: Colors.orange, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Auto-Scanning...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Found: ${_getFoundFieldsText()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _stopAutoScanning,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Stop Scanning',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            SizedBox(height: 20),

            if (_processedImagePath != null && _hasMissingValues()) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isProcessing ? null : () async {
                        if (_processedImagePath != null) {
                          setState(() {
                            isProcessing = true;
                          });
                          final inputImage = InputImage.fromFilePath(_processedImagePath!);
                          final recognizedText = await _textRecognizer.processImage(inputImage);
                          String allText = '';
                          for (TextBlock block in recognizedText.blocks) {
                            for (TextLine line in block.lines) {
                              allText += '${line.text}\n';
                            }
                          }
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
              ),
            ],
              ],
            ),
          ),
          
          // Results overlay (redesigned)
          if (_showingResults) ...[
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Container(
                  margin: EdgeInsets.all(20),
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFE8BE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Color(0xFFA5362D), width: 2),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getHeaderText(),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _getHeaderColor(),
                          ),
                        ),
                        SizedBox(height: 20),
                        
                        // Win amount display (if winner)
                        if (_isWinner == true && _winAmount != null) ...[
                          Container(
                            padding: EdgeInsets.all(16),
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green[300]!, width: 2),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.celebration, color: Colors.green[600], size: 32),
                                SizedBox(height: 8),
                                Text(
                                  'You Won!',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${_winAmount.toString().replaceAllMapped(
                                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                    (Match m) => '${m[1]},',
                                  )} VND',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        // Scanned ticket image (full width like other boxes)
                        if (_processedImagePath != null && _processedImagePath!.isNotEmpty) ...[
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                              border: Border.all(color: Color(0xFFA5362D), width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(_processedImagePath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: Center(
                                      child: Icon(Icons.error, color: Colors.red, size: 20),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                        ],
                        
                        // OCR verification in simple grid
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color(0xFFA5362D), width: 1),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _buildSimpleField('Province', city, Icons.location_on)),
                                  SizedBox(width: 8),
                                  Expanded(child: _buildSimpleField('Date', date, Icons.calendar_today)),
                                ],
                              ),
                              SizedBox(height: 8),
                              _buildSimpleField('Ticket Number', ticketNumber, Icons.confirmation_number),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Quantity selector (full width like verification box)
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color(0xFFA5362D), width: 1),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Quantity',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  GestureDetector(
                                    onTap: _ticketQuantity > 1 ? () {
                                      setState(() {
                                        _ticketQuantity--;
                                      });
                                    } : null,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: _ticketQuantity > 1 ? Color(0xFFA5362D) : Colors.grey[300],
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(Icons.remove, color: Colors.white, size: 16),
                                    ),
                                  ),
                                  Text(
                                    '$_ticketQuantity',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _ticketQuantity < 99 ? () {
                                      setState(() {
                                        _ticketQuantity++;
                                      });
                                    } : null,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: _ticketQuantity < 99 ? Color(0xFFA5362D) : Colors.grey[300],
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(Icons.add, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  // Create duplicates in background if quantity > 1
                                  if (_ticketQuantity > 1 && _storedTicketId != null) {
                                    print('🔄 Scan Another: Creating duplicates for total quantity $_ticketQuantity (background)');
                                    // Fire and forget - don't await
                                    TicketStorageService.duplicateTicket(_storedTicketId!, _ticketQuantity).then((duplicateSuccess) {
                                      print('🔄 BACKGROUND DUPLICATION RESULT: ${duplicateSuccess ? "SUCCESS" : "FAILED"}');
                                      if (duplicateSuccess) {
                                        print('✅ Should now have $_ticketQuantity total tickets in DB (1 original + ${_ticketQuantity - 1} duplicates)');
                                      }
                                    }).catchError((error) {
                                      print('❌ Background duplication error: $error');
                                    });
                                  }
                                  
                                  // Close overlay and scan another immediately
                                  setState(() {
                                    _showingResults = false;
                                    _processedImagePath = null;
                                    city = 'Not found';
                                    date = 'Not found';
                                    ticketNumber = 'Not found';
                                    rawText = '';
                                    _ticketQuantity = 1;
                                    _isCheckingWinner = false;
                                    _isWinner = null;
                                    _winAmount = null;
                                    _matchedTiers = null;
                                    _winnerCheckError = null;
                                  });
                                  _startAutoScanning();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFFA5362D),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Scan Another',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  // Create duplicates in background if quantity > 1
                                  if (_ticketQuantity > 1 && _storedTicketId != null) {
                                    print('🔄 Done: Creating duplicates for total quantity $_ticketQuantity (background)');
                                    // Fire and forget - don't await
                                    TicketStorageService.duplicateTicket(_storedTicketId!, _ticketQuantity).then((duplicateSuccess) {
                                      print('🔄 BACKGROUND DUPLICATION RESULT: ${duplicateSuccess ? "SUCCESS" : "FAILED"}');
                                      if (duplicateSuccess) {
                                        print('✅ Should now have $_ticketQuantity total tickets in DB (1 original + ${_ticketQuantity - 1} duplicates)');
                                      }
                                    }).catchError((error) {
                                      print('❌ Background duplication error: $error');
                                    });
                                  }
                                  
                                  // Go back to home immediately
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[600],
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Done',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }
  
  /// Get the proper Vietnamese province name from OCR result
  String _getProvinceInVietnamese(String ocrProvince) {
    // Map from OCR results (without diacritics) to proper Vietnamese names
    final Map<String, String> provinceMapping = {
      'An Giang': 'An Giang',
      'Bac Lieu': 'Bạc Liêu', 
      'Bac Ninh': 'Bắc Ninh',
      'Ben Tre': 'Bến Tre',
      'Binh Dinh': 'Bình Định',
      'Binh Duong': 'Bình Dương',
      'Binh Phuoc': 'Bình Phước',
      'Binh Thuan': 'Bình Thuận',
      'Ca Mau': 'Cà Mau',
      'Can Tho': 'Cần Thơ',
      'Da Lat': 'Đà Lạt',
      'Da Nang': 'Đà Nẵng',
      'Dak Lak': 'Đắk Lắk',
      'Dak Nong': 'Đắk Nông',
      'Dong Nai': 'Đồng Nai',
      'Dong Thap': 'Đồng Tháp',
      'Gia Lai': 'Gia Lai',
      'Hai Phong': 'Hải Phòng',
      'Hanoi': 'Hà Nội',
      'Hau Giang': 'Hậu Giang',
      'Ho Chi Minh': 'Hồ Chí Minh',
      'Hue': 'Huế',
      'Khanh Hoa': 'Khánh Hòa',
      'Kien Giang': 'Kiên Giang',
      'Kon Tum': 'Kon Tum',
      'Long An': 'Long An',
      'Nam Dinh': 'Nam Định',
      'Ninh Thuan': 'Ninh Thuận',
      'Phu Yen': 'Phú Yên',
      'Quang Binh': 'Quảng Bình',
      'Quang Nam': 'Quảng Nam',
      'Quang Ngai': 'Quảng Ngãi',
      'Quang Ninh': 'Quảng Ninh',
      'Quang Tri': 'Quảng Trị',
      'Soc Trang': 'Sóc Trăng',
      'Tay Ninh': 'Tây Ninh',
      'Thai Binh': 'Thái Bình',
      'Tien Giang': 'Tiền Giang',
      'Tra Vinh': 'Trà Vinh',
      'Vinh Long': 'Vĩnh Long',
      'Vung Tau': 'Vũng Tàu',
    };
    
    // First try exact match
    if (provinceMapping.containsKey(ocrProvince)) {
      final vietnameseName = provinceMapping[ocrProvince]!;
      print('🇻🇳 Mapped "$ocrProvince" → "$vietnameseName"');
      return vietnameseName;
    }
    
    // Try case-insensitive match
    for (final entry in provinceMapping.entries) {
      if (entry.key.toLowerCase() == ocrProvince.toLowerCase()) {
        final vietnameseName = entry.value;
        print('🇻🇳 Mapped "$ocrProvince" → "$vietnameseName" (case-insensitive)');
        return vietnameseName;
      }
    }
    
    // Try normalized matching (remove diacritics from both sides)
    final normalizedOcr = TicketStorageService.normalizeVietnameseText(ocrProvince);
    for (final entry in provinceMapping.entries) {
      final normalizedEntry = TicketStorageService.normalizeVietnameseText(entry.key);
      if (normalizedEntry == normalizedOcr) {
        final vietnameseName = entry.value;
        print('🇻🇳 Mapped "$ocrProvince" → "$vietnameseName" (normalized)');
        return vietnameseName;
      }
    }
    
    print('⚠️ No Vietnamese mapping found for "$ocrProvince", using as-is');
    return ocrProvince;
  }

  /// Check if a ticket is a winner using AWS API
  Future<void> _checkTicketWinner(String ticketNumber, String province, String drawDate) async {
    setState(() {
      _isCheckingWinner = true;
      _winnerCheckError = null;
    });

    try {
      if (!_shouldCheckWinner(drawDate)) {
        print('⏰ Winner checking skipped - results not available yet');
        setState(() {
          _isCheckingWinner = false;
          _winnerCheckError = 'Results not available yet';
        });
        return;
      }

      final region = TicketStorageService.getRegionForCity(province, _citiesData);
      if (region == null) {
        print('❌ Cannot determine region for city: $province');
        setState(() {
          _isCheckingWinner = false;
          _winnerCheckError = 'Cannot determine region';
        });
        return;
      }
      
      final payload = {
        'ticket': ticketNumber,
        'province': province,
        'date': drawDate,
        'region': region,
      };
      
      print('🎯 Checking winner with payload: $payload');
      
      // Get AWS credentials
      final credentials = await TicketStorageService.getAwsCredentials();
      
      final apiGatewayUrl = 'https://u9maewv4ch.execute-api.ap-southeast-1.amazonaws.com/dev';
      
      final awsSigV4Client = AwsSigV4Client(
        credentials.accessKeyId!,
        credentials.secretAccessKey!,
        apiGatewayUrl,
        sessionToken: credentials.sessionToken!,
        region: 'ap-southeast-1',
      );
      
      final signedRequest = SigV4Request(
        awsSigV4Client,
        method: 'POST',
        path: '/checkTicket',
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );
      
      final response = await http.post(
        Uri.parse(signedRequest.url!),
        headers: signedRequest.headers?.cast<String, String>(),
        body: signedRequest.body,
      );
      
      print('🎯 Winner check response: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        setState(() {
          _isWinner = responseData['Winner'] as bool;
          _winAmount = responseData['Sum'] as int?;
          _matchedTiers = (responseData['MatchedTiers'] as List?)?.cast<String>();
          _isCheckingWinner = false;
        });
        
        if (_isWinner == true) {
          print('🎉 WINNER! Amount: $_winAmount, Tiers: $_matchedTiers');
        } else {
          print('❌ Not a winner');
        }
      } else {
        setState(() {
          _isCheckingWinner = false;
          _winnerCheckError = 'Check failed: ${response.statusCode}';
        });
        print('❌ Winner check failed: ${response.statusCode} - ${response.body}');
      }
      
    } catch (e) {
      setState(() {
        _isCheckingWinner = false;
        _winnerCheckError = 'Error: $e';
      });
      print('❌ Error checking winner: $e');
    }
  }
  
  /// Check if winner checking should be performed based on date and time
  bool _shouldCheckWinner(String drawDate) {
    try {
      // Parse the ticket date (expected format: YYYY-MM-DD)
      final dateParts = drawDate.split('-');
      if (dateParts.length != 3) return false;
      
      final ticketDate = DateTime(
        int.parse(dateParts[0]), // year
        int.parse(dateParts[1]), // month
        int.parse(dateParts[2])  // day
      );
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Check if ticket date is before today
      if (ticketDate.isBefore(today)) {
        return true;
      }
      
      // Check if ticket date is today and current time is after 4:15 PM
      if (ticketDate.isAtSameMomentAs(today)) {
        final cutoffTime = DateTime(now.year, now.month, now.day, 16, 15); // 4:15 PM
        return now.isAfter(cutoffTime);
      }
      
      return false;
    } catch (e) {
      print('Error parsing date for winner check: $e');
      return false;
    }
  }

  /// Show winner popup dialog
  void _showWinnerPopup(int? winAmount, List<String>? matchedTiers) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFFFFE8BE),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Color(0xFFA5362D), width: 2),
          ),
          title: Row(
            children: [
              Icon(Icons.celebration, color: Colors.orange, size: 30),
              SizedBox(width: 10),
              Text(
                'Congratulations!',
                style: TextStyle(
                  color: Color(0xFFA5362D),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your ticket is a WINNER!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              if (winAmount != null) ...[
                SizedBox(height: 15),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Text(
                    'Prize: ${winAmount.toString().replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (Match m) => '${m[1]},',
                    )} VND',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (matchedTiers != null && matchedTiers.isNotEmpty) ...[
                SizedBox(height: 15),
                Text(
                  'Matched: ${matchedTiers.join(', ')}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Amazing!',
                style: TextStyle(
                  color: Color(0xFFA5362D),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build simple field for clean grid layout
  Widget _buildSimpleField(String label, String value, IconData icon) {
    final isFound = value != 'Not found';
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isFound ? Color(0xFFF8F9FA) : Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isFound ? Colors.green[300]! : Colors.red[300]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isFound ? Colors.green[700] : Colors.red[700],
                size: 16,
              ),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                isFound ? Icons.check_circle : Icons.cancel,
                color: isFound ? Colors.green[600] : Colors.red[600],
                size: 14,
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: isFound ? Colors.black87 : Colors.red[700],
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Build compact info row for side-by-side layout
  Widget _buildCompactInfoRow(String label, String value, IconData icon) {
    final isFound = value != 'Not found';
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isFound ? Colors.green[100] : Colors.red[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            color: isFound ? Colors.green[700] : Colors.red[700],
            size: 14,
          ),
        ),
        SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: isFound ? Colors.black87 : Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isFound ? Colors.green[600] : Colors.red[600],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isFound ? Icons.check : Icons.close,
            color: Colors.white,
            size: 12,
          ),
        ),
      ],
    );
  }

  /// Build info row for the redesigned popup with enhanced verification
  Widget _buildInfoRow(String label, String value, IconData icon) {
    final isFound = value != 'Not found';
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isFound ? Color(0xFFF8F9FA) : Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFound ? Colors.green[300]! : Colors.red[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isFound ? Colors.green[100] : Colors.red[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: isFound ? Colors.green[700] : Colors.red[700],
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFound ? Colors.white : Colors.red[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isFound ? Colors.grey[300]! : Colors.red[200]!,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      color: isFound ? Colors.black87 : Colors.red[700],
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isFound ? Colors.green[600] : Colors.red[600],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isFound ? Icons.check : Icons.close,
              color: Colors.white,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Background processing after scan success (save image, store in DB, check winner)
  Future<void> _performBackgroundProcessing(
    Map<String, dynamic> voted,
    String cityResult,
    String dateResult,
    String ticketResult,
  ) async {
    String? savedImagePath;
    
    try {
      // Save image permanently
      final tempImagePath = voted['imagePath'] ?? '';
      if (tempImagePath.isNotEmpty) {
        final tempFile = File(tempImagePath);
        if (await tempFile.exists()) {
          final imageBytes = await tempFile.readAsBytes();
          savedImagePath = await ImageStorageService.saveTicketImage(
            imageBytes: imageBytes,
            ticketId: '${ticketResult}_${DateTime.now().millisecondsSinceEpoch}',
          );
          if (savedImagePath != null) {
            print('✅ Ticket image saved permanently: $savedImagePath');
            // Update the processed image path for the popup
            setState(() {
              _processedImagePath = savedImagePath;
            });
          }
        }
      }
      
      // Convert OCR result to proper Vietnamese name for API/DB storage
      final String provinceForApi = _getProvinceInVietnamese(cityResult);
      final String apiDate = TicketStorageService.convertDateToApiFormat(dateResult);
      final region = TicketStorageService.getRegionForCity(provinceForApi, _citiesData);
      
      if (region != null) {
        print('📤 DB STORAGE: Storing ticket with imagePath: $savedImagePath');
        print('=== DB STORAGE PAYLOAD ===');
        print('ticketNumber: $ticketResult');
        print('province: $provinceForApi');
        print('drawDate: $apiDate');
        print('region: $region');
        print('ocrRawText: ${voted['rawText'] ?? ''}');
        print('imagePath: $savedImagePath');
        print('========================');
        
        final storedTicketId = await TicketStorageService.storeTicket(
          ticketNumber: ticketResult,
          province: provinceForApi,
          drawDate: apiDate,
          region: region,
          ocrRawText: voted['rawText'] ?? '',
          imagePath: savedImagePath,
        );
        
        print('🔄 DB STORAGE RESULT: ${storedTicketId != null ? "SUCCESS" : "FAILED"}');
        
        // Check for winners after successful storage
        if (storedTicketId != null) {
          // Store the ticket ID for duplication
          _storedTicketId = storedTicketId;
          
          print('🎯 Checking for winners...');
          await _checkTicketWinner(ticketResult, provinceForApi, apiDate);
          
          // Store ticket ID for later duplication when user clicks action buttons
          print('💾 Stored ticket ID for potential duplication: $storedTicketId');
          print('🔢 Current total quantity selected: $_ticketQuantity');
        }
      } else {
        print('❌ No region found for province: $provinceForApi');
        setState(() {
          _winnerCheckError = 'Cannot determine region for $provinceForApi';
        });
      }
    } catch (e) {
      print('❌ Error in background processing: $e');
      setState(() {
        _winnerCheckError = 'Processing error: $e';
      });
    }
  }

  /// Get the header text based on winner status
  String _getHeaderText() {
    if (_isWinner == true) {
      return 'Winner!';
    } else if (_isWinner == false) {
      return 'Not a Winner';
    } else {
      return 'Scan Complete!';
    }
  }

  /// Get the header color based on winner status
  Color _getHeaderColor() {
    if (_isWinner == true) {
      return Colors.green[700]!;
    } else if (_isWinner == false) {
      return Colors.red[700]!;
    } else {
      return Color(0xFFA5362D);
    }
  }

  // Old manual duplication method removed - now using Lambda function
}
