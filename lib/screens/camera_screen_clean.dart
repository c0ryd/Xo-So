import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../services/ticket_storage_service.dart';
import '../services/image_storage_service.dart';
import '../utils/image_preprocessing.dart';
import '../utils/ocr_enhancements.dart';
import '../utils/date_validator.dart';
import '../services/ad_service.dart';
import '../widgets/vietnamese_tiled_background.dart';
import '../config/app_config.dart';
import '../main.dart'; // For cameras list
import '../services/s3_upload_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
    // Increased frame size to match the new crop area for better OCR
    final frameWidth = size.width * 0.85;  // Keep visual overlay at 85% for user guidance
    final frameHeight = frameWidth * 1.54; // Maintain aspect ratio (0.65 inverse)
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
  final String? manualCity;
  final String? manualDate;
  final String? manualTicketNumber;
  final bool isManualEntry;

  const CameraScreen({
    Key? key,
    this.manualCity,
    this.manualDate,
    this.manualTicketNumber,
    this.isManualEntry = false,
  }) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
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
  String? _prizeCategory; // Store the prize category (e.g., "G6", "DB", etc.)
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

  // App lifecycle state
  late AppLifecycleState _appLifecycleState;
  bool _wasAutoScanningBeforePause = false; // Track if we were scanning before going to background

  // Focus indicator state (like native camera app)
  bool _showFocusIndicator = false;
  Offset _focusIndicatorPosition = Offset(0.5, 0.5);
  Timer? _focusIndicatorTimer;

  // Rolling result stacking - keep results fresh by forgetting old ones
  final int _rollingWindowSize = 5; // Keep results from last 5 scans
  final List<Map<String, String>> _rollingResults = []; // Store scan results with frame numbers
  Map<String, String> _bestStackedResults = {
    'city': 'Not found',
    'date': 'Not found', 
    'ticketNumber': 'Not found'
  };
  int _currentFrameNumber = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appLifecycleState = WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    
    _loadCitiesData();
    _loadProvinceSchedule();
    _createBannerAd(); // Create ad early for faster loading
    
    // Handle manual entry data if provided
    if (widget.isManualEntry && 
        widget.manualCity != null && 
        widget.manualDate != null && 
        widget.manualTicketNumber != null) {
      // Set the manual data immediately
      city = widget.manualCity!;
      date = widget.manualDate!;
      ticketNumber = widget.manualTicketNumber!;
      rawText = 'Manual Entry: ${widget.manualTicketNumber}, ${widget.manualCity}, ${widget.manualDate}';
      _showingResults = true;
      
      // Initialize camera but don't start auto-scanning for manual entry
      _initializeCamera();
      
      // Start processing the manual entry data after camera is initialized
      Future.delayed(Duration(milliseconds: 1000), () {
        if (mounted) {
          _processManualEntry();
        }
      });
    } else {
      // Initialize camera automatically when screen loads (normal mode)
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    _autoScanTimer?.cancel();
    _focusIndicatorTimer?.cancel();
    _cameraController?.dispose();
    _textRecognizer.close();
    _disposeBannerAd();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('🔄 App lifecycle state changed from ${_appLifecycleState.name} to ${state.name}');
    print('🔍 Current auto-scanning state: $_isAutoScanning');
    print('🔍 Camera initialized: ${_cameraController?.value.isInitialized ?? false}');
    print('🔍 Showing results: $_showingResults');
    print('🔍 Was scanning before pause flag: $_wasAutoScanningBeforePause');
    
    if (_appLifecycleState != state) {
      final previousState = _appLifecycleState;
      _appLifecycleState = state;
      
      switch (state) {
        case AppLifecycleState.inactive:
        case AppLifecycleState.paused:
        case AppLifecycleState.detached:
        case AppLifecycleState.hidden:
          // ANY non-resumed state should stop scanning
          print('🛑 App NOT ACTIVE (${state.name}) - stopping auto-scanning');
          print('🔍 Was auto-scanning before stopping: $_isAutoScanning');
          
          // ALWAYS remember if we were auto-scanning when we stop
          if (_isAutoScanning) {
            _wasAutoScanningBeforePause = true;
            print('🔍 Setting _wasAutoScanningBeforePause = true');
          }
          
          // Force stop auto-scanning and cancel any timers
          _forceStopAutoScanning();
          break;
          
        case AppLifecycleState.resumed:
          // App is back in foreground
          print('▶️ App RESUMED - was previously scanning: $_wasAutoScanningBeforePause');
          
          // Only restart auto-scanning if we were scanning before AND camera is ready
          if (_wasAutoScanningBeforePause && 
              _cameraController != null && 
              _cameraController!.value.isInitialized &&
              !_showingResults &&
              !_isAutoScanning) {
            print('🔄 Restarting auto-scanning after resume in 1 second');
            Future.delayed(Duration(milliseconds: 1000), () {
              if (mounted && 
                  _appLifecycleState == AppLifecycleState.resumed && 
                  !_isAutoScanning &&
                  _wasAutoScanningBeforePause) {
                print('🔄 Actually starting auto-scanning now');
                _startAutoScanning();
                _wasAutoScanningBeforePause = false; // Reset flag after restart
              }
            });
          } else {
            print('🚫 Not restarting scanning: wasScanning=$_wasAutoScanningBeforePause, cameraReady=${_cameraController?.value.isInitialized}, showingResults=$_showingResults, currentlyScanning=$_isAutoScanning');
            // Reset flag if we're not going to restart
            _wasAutoScanningBeforePause = false;
          }
          break;
      }
    }
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
        
        // Set focus mode for close-up OCR text reading
        await _cameraController!.setFocusMode(FocusMode.auto);
        print('📷 Using auto focus optimized for close-up OCR');
        
        // Set initial focus for very close reading (1-2 inches) - maximum closeness
        try {
          // Start with much closer focus - 5 aggressive attempts for closest possible focus
          await _cameraController!.setFocusPoint(Offset(0.5, 0.5));
          await Future.delayed(Duration(milliseconds: 150));
          await _cameraController!.setFocusPoint(Offset(0.5, 0.5));
          await Future.delayed(Duration(milliseconds: 150));
          await _cameraController!.setFocusPoint(Offset(0.5, 0.5));
          await Future.delayed(Duration(milliseconds: 150));
          await _cameraController!.setFocusPoint(Offset(0.5, 0.5));
          await Future.delayed(Duration(milliseconds: 150));
          await _cameraController!.setFocusPoint(Offset(0.5, 0.5));
          await Future.delayed(Duration(milliseconds: 400)); // Longer final settle time
          
          print('📷 Camera focus optimized for VERY close text reading (1-2 inches)');
        } catch (e) {
          print('⚠️ Could not set focus point: $e');
        }
        
        setState(() {
          _isCameraInitialized = true;
        });
        
        // Start auto-scanning automatically after a short delay, but only if app is active and not manual entry
        if (!widget.isManualEntry) {
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted && _appLifecycleState == AppLifecycleState.resumed) {
              _startAutoScanning();
            }
          });
        }
      } catch (e) {
        print('Error initializing camera: $e');
      }
    }
  }

  void _startAutoScanning() {
    print('🔄 _startAutoScanning called - current state: $_isAutoScanning');
    print('🔄 App lifecycle state: ${_appLifecycleState.name}');
    
    if (_isAutoScanning) {
      print('🔄 Already scanning, returning');
      return; // Already running
    }
    
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
      _prizeCategory = null;
      _matchedTiers = null;
      _winnerCheckError = null;
      _ticketQuantity = 1;
      // Reset rolling stacking state
      _rollingResults.clear();
      _bestStackedResults = {
        'city': 'Not found',
        'date': 'Not found', 
        'ticketNumber': 'Not found'
      };
      _currentFrameNumber = 0;
    });
    
    // Create banner ad when scanning starts
    _createBannerAd();
    
    print('=== AUTO-SCANNING STARTED (with result stacking) ===');
    _performAutoScan();
  }

  void _stopAutoScanning() {
    _autoScanTimer?.cancel();
    if (mounted) {
      setState(() {
        _isAutoScanning = false;
      });
    }
    
    // Dispose banner ad when scanning stops
    _disposeBannerAd();
    
    print('=== AUTO-SCANNING STOPPED ===');
  }

  void _forceStopAutoScanning() {
    // More aggressive stop that ensures everything is cancelled
    print('🛑 Force stopping auto-scanning - timer active: ${_autoScanTimer?.isActive ?? false}');
    _autoScanTimer?.cancel();
    _autoScanTimer = null;
    
    if (mounted) {
      setState(() {
        _isAutoScanning = false;
      });
      print('🛑 Set _isAutoScanning = false');
    } else {
      print('🛑 Widget not mounted, cannot setState');
    }
    
    print('🛑 Force stopped auto-scanning complete');
  }

  Future<void> _performAutoScan() async {
    if (!_isAutoScanning || _autoScanAttempts >= _maxAutoScanAttempts) {
      print('Auto-scan stopping: isAutoScanning=$_isAutoScanning, attempts=$_autoScanAttempts');
      _stopAutoScanning();
      return;
    }
    
    // Check if app is still active before scanning
    if (_appLifecycleState != AppLifecycleState.resumed) {
      print('Auto-scan stopping: app not in foreground (${_appLifecycleState.name})');
      _forceStopAutoScanning();
      return;
    }
    
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('Auto-scan stopping: camera not initialized');
      _stopAutoScanning();
      return;
    }
    
    // Optimize camera settings for close-up OCR
    try {
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);
      
      // Simple close focus for 2-4 inch reading
      await _cameraController!.setFocusPoint(Offset(0.3, 0.5));
      await Future.delayed(Duration(milliseconds: 150));
      
      // Second focus attempt for stability
      await _cameraController!.setFocusPoint(Offset(0.3, 0.5));
      await Future.delayed(Duration(milliseconds: 150));
    } catch (e) {
      print('⚠️ Could not optimize camera settings: $e');
    }
    
    setState(() {
      _autoScanAttempts++;
    });
    print('Auto-scan attempt ${_autoScanAttempts}/${_maxAutoScanAttempts}');
    
    try {
      // Take 3 pictures with different exposure compensations for better OCR accuracy
      final List<Map<String, dynamic>> ocrResults = [];
      // Use 3 different exposures for better OCR accuracy  
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
      
      // Update rolling results window
      _updateRollingResults(cityResult, dateResult, ticketResult);
      
      // Count how many fields we have in our rolling stack
      final stackedCount = _bestStackedResults.values.where((v) => v != 'Not found').length;
      
      // Check if we have complete information
      if (stackedCount == 3) {
        print('=== ROLLING STACK SUCCESS! Complete ticket info across ${_rollingResults.length} frames ===');
        
        // Vibrate to indicate successful scan
        HapticFeedback.mediumImpact();
        
        _stopAutoScanning();
        setState(() {
          city = _bestStackedResults['city']!;
          date = _bestStackedResults['date']!;
          ticketNumber = _bestStackedResults['ticketNumber']!;
          rawText = voted['rawText'] ?? '';
          isProcessing = false;
          _showingResults = true;
          _processedImagePath = voted['imagePath'];
        });

        // Start background processing with rolling stacked results
        final stackedVoted = Map<String, dynamic>.from(voted);
        stackedVoted['city'] = _bestStackedResults['city'];
        stackedVoted['date'] = _bestStackedResults['date'];
        stackedVoted['ticketNumber'] = _bestStackedResults['ticketNumber'];
        _performBackgroundProcessing(stackedVoted, _bestStackedResults['city']!, _bestStackedResults['date']!, _bestStackedResults['ticketNumber']!);
        return;
      }

      // Schedule next scan faster, but only if app is still active
      if (_isAutoScanning && 
          _autoScanAttempts < _maxAutoScanAttempts && 
          _appLifecycleState == AppLifecycleState.resumed) {
        print('Scheduling next auto-scan in 500 ms...');
        _autoScanTimer = Timer(Duration(milliseconds: 500), () {
          if (_appLifecycleState == AppLifecycleState.resumed) {
            _performAutoScan();
          } else {
            print('App not resumed, cancelling scheduled scan');
            _forceStopAutoScanning();
          }
        });
      } else {
        print('Auto-scan stopped: scanning=$_isAutoScanning, attempts=${_autoScanAttempts}, maxAttempts=${_maxAutoScanAttempts}, appState=${_appLifecycleState.name}');
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
        // Increased crop area to capture more detail - ticket fills more of the frame
        final imageWidth = originalImage.width;
        final imageHeight = originalImage.height;
        
        final frameHeight = (imageHeight * 0.90).round(); // Increased from 0.85 to 0.90 for very close reading
        final frameWidth = (frameHeight * 0.65).round();  // Maintain aspect ratio
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
        
        // Apply light image enhancement for better OCR
        final enhancedImage = img.adjustColor(
          croppedImage,
          contrast: 1.2,        // Slight contrast boost for better text definition
          brightness: 1.05,     // Very slight brightness boost
          saturation: 0.9,      // Slightly reduce saturation to focus on text
        );
        
        // Dynamically determine the best rotation (90° or 270°) for OCR
        final bestRotationResult = await _findBestRotation(enhancedImage);
        final rotatedImage = bestRotationResult['image'] as img.Image;
        final rotationAngle = bestRotationResult['angle'] as int; // not used further, for logs
        final recognizedText = bestRotationResult['text'] as RecognizedText;
        
        print('🔄 Best rotation determined: ${rotationAngle}°');
        
        // Save the best rotated image to temporary file with maximum quality for better OCR
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final tempFile = File('${tempDir.path}/lottery_${timestamp}.jpg');
        await tempFile.writeAsBytes(img.encodeJpg(rotatedImage, quality: 100)); // Maximum quality
        
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
          print('🔍 OCR TEXT PREVIEW: ${allText.substring(0, math.min(200, allText.length))}');
        }
        print('=== FULL OCR TEXT START ===');
        print(allText);
        print('=== FULL OCR TEXT END ===');
        
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
    if (mounted) {
      setState(() {
        _isBannerAdReady = false;
      });
    }
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
    
    // Extract date - Vietnamese lottery dates can be in multiple formats
    final datePatterns = [
      RegExp(r'(\d{1,2}[-/]\d{1,2}[-/]\d{4})'),                    // DD-MM-YYYY or DD/MM/YYYY
      RegExp(r'(\d{4}[-/]\d{1,2}[-/]\d{1,2})'),                    // YYYY-MM-DD or YYYY/MM/DD
      RegExp(r'(\d{1,2}\s*-\s*\d{1,2}\s*-\s*\d{4})'),             // DD - MM - YYYY with spaces
      RegExp(r'Mở ngày\s*(\d{1,2}[-/]\d{1,2}[-/]\d{4})'),         // "Mở ngày DD-MM-YYYY"
      RegExp(r'[Nn]gày\s*(\d{1,2}[-/]\d{1,2}[-/]\d{4})'),         // "Ngày DD-MM-YYYY"
      RegExp(r'[Dd]ate\s*[:\-]?\s*(\d{1,2}[-/]\d{1,2}[-/]\d{4})'), // "Date: DD-MM-YYYY"
      RegExp(r'(\d{1,2}[-/]\d{1,2}[-/]\d{2})'),                    // DD-MM-YY (2-digit year)
      RegExp(r'(\d{1,2}\.\d{1,2}\.\d{4})'),                        // DD.MM.YYYY
      RegExp(r'(\d{1,2}\s+\d{1,2}\s+\d{4})'),                     // DD MM YYYY (spaces)
    ];
    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final potentialDate = match.group(1) ?? 'Not found';
        
        // Validate the date is within acceptable range (Today-60 to Today+2)
        if (DateValidator.isValidLotteryDate(potentialDate)) {
          foundDate = potentialDate;
          print('✅ Valid lottery date found: $potentialDate');
          break;
        } else {
          print('❌ Invalid lottery date rejected: $potentialDate (Valid range: ${DateValidator.getValidDateRange()})');
          if (DateValidator.isTooOld(potentialDate)) {
            print('   → Reason: Date is too old (>60 days ago)');
          } else if (DateValidator.isTooFuture(potentialDate)) {
            print('   → Reason: Date is too far in future (>2 days ahead)');
          }
          // Continue searching for a valid date
          continue;
        }
      }
    }
    
    // Extract ticket number - Vietnamese lottery tickets can be 5-6 digits
    final ticketPatterns = [
      RegExp(r'\b(\d{6})\b'),                    // 6-digit number with word boundaries
      RegExp(r'(\d{6})\s*[A-Z]'),               // 6 digits followed by letter
      RegExp(r'\b(\d{5})\b'),                   // 5-digit number with word boundaries
      RegExp(r'(\d{5})\s*[A-Z]'),               // 5 digits followed by letter
      RegExp(r'[Ss][Oo]\s*(\d{6})'),           // "SO 123456" format
      RegExp(r'[Ss][Oo]\s*(\d{5})'),           // "SO 12345" format
      RegExp(r'[Nn][Uu][Mm][Bb][Ee][Rr]\s*[:\-]?\s*(\d{5,6})'), // "Number: 123456"
      RegExp(r'[Tt][Ii][Cc][Kk][Ee][Tt]\s*[:\-]?\s*(\d{5,6})'), // "Ticket: 123456"
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
        await tempFile.writeAsBytes(img.encodeJpg(rotatedImage, quality: 100));
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
  
  String _findCityFromFilteredList(String text, List<String> validProvinces) {
    if (validProvinces.isEmpty) {
      return 'Not found'; // No valid provinces for this date
    }
    
    final upperText = text.toUpperCase();
    
    print('🔍 CITY DETECTION: Searching in ${validProvinces.length} provinces');
    if (upperText.length > 20) {
      print('🔍 OCR text preview: ${upperText.substring(0, math.min(200, upperText.length))}...');
    } else {
      print('🔍 OCR text preview: "$upperText" (SHORT/EMPTY)');
    }
    
    // Create enhanced mappings with OCR variations for valid provinces only
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
      'Tiền Giang': ['TIEN GIANG', 'TIỀN GIANG', 'TIÊN GIANG', 'TIEN CIANG'],
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
      'Khánh Hòa': ['KHANH HOA', 'KHÁNH HÒA'],
      'Phú Yên': ['PHU YEN', 'PHÚ YÊN'],
      'Bình Định': ['BINH DINH', 'BÌNH ĐỊNH'],
      'Quảng Nam': ['QUANG NAM', 'QUẢNG NAM'],
      'Quảng Ngãi': ['QUANG NGAI', 'QUẢNG NGÃI'],
      'Thừa Thiên Huế': ['THUA THIEN HUE', 'THỪA THIÊN HUẾ', 'HUE', 'HUẾ'],
      'Đắk Lắk': ['DAK LAK', 'ĐẮK LẮK', 'DAKLAK'],
      'Đắk Nông': ['DAK NONG', 'ĐẮK NÔNG'],
      'Gia Lai': ['GIA LAI'],
      'Kon Tum': ['KON TUM', 'KONTUM'],
      'Nghệ An': ['NGHE AN', 'NGHỆ AN'],
      'Hà Tĩnh': ['HA TINH', 'HÀ TĨNH'],
      'Quảng Trị': ['QUANG TRI', 'QUẢNG TRỊ'],
      'Quảng Bình': ['QUANG BINH', 'QUẢNG BÌNH'],
    };
    
    // Filter variations to only include valid provinces for this date
    final filteredVariations = <String, List<String>>{};
    for (final entry in cityVariations.entries) {
      if (validProvinces.contains(entry.key)) {
        filteredVariations[entry.key] = entry.value;
      }
    }
    
    // First pass: exact matching with variations
    for (final entry in filteredVariations.entries) {
      final cityName = entry.key;
      final variations = entry.value;
      
      for (final variation in variations) {
        if (upperText.contains(variation)) {
          print('✅ EXACT MATCH: Found "$cityName" via variation "$variation"');
          return cityName;
        }
      }
    }
    
    // Special aggressive matching for Ho Chi Minh City variants (only if valid for this date)
    if (validProvinces.contains('TP. Hồ Chí Minh') &&
        (upperText.contains('CHI MIN') || 
         upperText.contains('CHI MINH') || 
         upperText.contains('CHI MINT') ||
         upperText.contains('HO CHI') ||
         upperText.contains('TPHCM') ||
         (upperText.contains('CHI') && upperText.contains('MIN')))) {
      print('✅ SPECIAL MATCH: Ho Chi Minh City detected');
      return 'TP. Hồ Chí Minh';
    }
    
    // If no exact match, try fuzzy matching with valid provinces only
    double bestScore = 0.0;
    String bestMatch = 'Not found';
    
    for (final cityName in validProvinces) {
      final normalizedCity = _normalizeForOCR(cityName);
      final normalizedText = _normalizeForOCR(upperText);
      
      final score = _calculateSimilarity(normalizedText, normalizedCity);
      if (score > bestScore && score > 0.6) { // 60% threshold for matching
        bestScore = score;
        bestMatch = cityName;
      }
      
      // Also check variations if they exist
      if (filteredVariations.containsKey(cityName)) {
        for (final variation in filteredVariations[cityName]!) {
          final score = _calculateSimilarity(upperText, variation);
          if (score > bestScore && score > 0.6) {
            bestScore = score;
            bestMatch = cityName;
          }
        }
      }
    }
    
    if (bestMatch != 'Not found') {
      print('✅ FUZZY MATCH: Found "$bestMatch" (score: ${bestScore.toStringAsFixed(2)})');
      return bestMatch;
    }
    
    print('❌ NO MATCH: No city found in ${validProvinces.length} valid provinces');
    return 'Not found';
  }
  
  String _normalizeForOCR(String text) {
    return text
        .toUpperCase()
        // Common OCR number/letter substitutions
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll('5', 'S')
        .replaceAll('8', 'B')
        .replaceAll('6', 'G')
        .replaceAll('2', 'Z')
        // Vietnamese diacritics normalization
        .replaceAll('Ơ', 'O')
        .replaceAll('Ư', 'U')
        .replaceAll('Đ', 'D')
        .replaceAll('À', 'A')
        .replaceAll('Ả', 'A')
        .replaceAll('Ã', 'A')
        .replaceAll('Á', 'A')
        .replaceAll('Ạ', 'A')
        .replaceAll('Ă', 'A')
        .replaceAll('Ấ', 'A')
        .replaceAll('Ầ', 'A')
        .replaceAll('Ẩ', 'A')
        .replaceAll('Ẫ', 'A')
        .replaceAll('Ậ', 'A')
        .replaceAll('Ắ', 'A')
        .replaceAll('Ằ', 'A')
        .replaceAll('Ẳ', 'A')
        .replaceAll('Ẵ', 'A')
        .replaceAll('Ặ', 'A')
        .replaceAll('È', 'E')
        .replaceAll('É', 'E')
        .replaceAll('Ẻ', 'E')
        .replaceAll('Ẽ', 'E')
        .replaceAll('Ẹ', 'E')
        .replaceAll('Ề', 'E')
        .replaceAll('Ế', 'E')
        .replaceAll('Ể', 'E')
        .replaceAll('Ễ', 'E')
        .replaceAll('Ệ', 'E')
        .replaceAll('Ì', 'I')
        .replaceAll('Í', 'I')
        .replaceAll('Ỉ', 'I')
        .replaceAll('Ĩ', 'I')
        .replaceAll('Ị', 'I')
        .replaceAll('Ò', 'O')
        .replaceAll('Ó', 'O')
        .replaceAll('Ỏ', 'O')
        .replaceAll('Õ', 'O')
        .replaceAll('Ọ', 'O')
        .replaceAll('Ồ', 'O')
        .replaceAll('Ố', 'O')
        .replaceAll('Ổ', 'O')
        .replaceAll('Ỗ', 'O')
        .replaceAll('Ộ', 'O')
        .replaceAll('Ờ', 'O')
        .replaceAll('Ớ', 'O')
        .replaceAll('Ở', 'O')
        .replaceAll('Ỡ', 'O')
        .replaceAll('Ợ', 'O')
        .replaceAll('Ù', 'U')
        .replaceAll('Ú', 'U')
        .replaceAll('Ủ', 'U')
        .replaceAll('Ũ', 'U')
        .replaceAll('Ụ', 'U')
        .replaceAll('Ừ', 'U')
        .replaceAll('Ứ', 'U')
        .replaceAll('Ử', 'U')
        .replaceAll('Ữ', 'U')
        .replaceAll('Ự', 'U')
        .replaceAll('Ỳ', 'Y')
        .replaceAll('Ý', 'Y')
        .replaceAll('Ỷ', 'Y')
        .replaceAll('Ỹ', 'Y')
        .replaceAll('Ỵ', 'Y')
        // Remove spaces and special characters
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll('-', '')
        .replaceAll('_', '');
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
        title: Text(AppLocalizations.of(context)!.scanTicketButton, style: TextStyle(color: Color(0xFFFFD966))),
        iconTheme: IconThemeData(color: Color(0xFFFFD966)), // Gold back button
        leading: (_isCameraInitialized) ? BackButton(
          color: Color(0xFFFFD966), // Gold back button
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
            if (_processedImagePath != null && !_showingResults) ...[
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFFFE8BE), width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FutureBuilder<File?>(
                    future: ImageStorageService.getTicketImage(_processedImagePath!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          height: 100,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      
                      if (snapshot.hasData && snapshot.data != null) {
                        return Image.file(
                          snapshot.data!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                        );
                      } else {
                        return Container(
                          height: 100,
                          child: Center(
                            child: Icon(Icons.image_not_supported, color: Colors.grey[600]),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              SizedBox(height: 8),
            ],

                          if ((_isAutoScanning || _isCameraInitialized) && _isBannerAdReady && _bannerAd != null && !_showingResults) ...[
              Container(
                alignment: Alignment.center,
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
              SizedBox(height: 16),
            ],

            if (_isCameraInitialized && _cameraController != null && !_showingResults) ...[
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
                          await _handleCameraTap(details);
                        },
                        child: CameraPreview(_cameraController!),
                      ),
                      CustomPaint(
                        size: Size.infinite,
                        painter: LotteryTicketOverlayPainter(),
                      ),
                      // Focus indicator (like native camera app)
                      if (_showFocusIndicator)
                        Positioned(
                          left: _focusIndicatorPosition.dx - 40,
                          top: _focusIndicatorPosition.dy - 40,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.yellow.shade600,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Container(
                              margin: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.yellow.shade600,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              if (_isAutoScanning && !_showingResults) ...[
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Color(0xFFFFD966), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
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
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD966)),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context)!.autoScanning,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFD966),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${AppLocalizations.of(context)!.found}: ${_getFoundFieldsText()}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _stopAutoScanning,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.stopScanning,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            SizedBox(height: 20),

            if (_processedImagePath != null && _hasMissingValues() && !_showingResults) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isProcessing ? null : () async {
                        if (_processedImagePath != null) {
                          // Light haptic feedback for manual scan start
                          HapticFeedback.lightImpact();
                          
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
                          
                          // Medium haptic feedback when manual scan completes
                          HapticFeedback.mediumImpact();
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
              color: Colors.red.withOpacity(0.3),
              child: Center(
                child: Container(
                  margin: EdgeInsets.all(20),
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Color(0xFFFFD966), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
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
                        
                        // Win amount display (if winner) - same width as verification box
                        if (_isWinner == true && _winAmount != null) ...[
                          Container(
                            padding: EdgeInsets.all(16),
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade400, width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.celebration, color: Colors.green.shade400, size: 24),
                                    SizedBox(width: 8),
                                    Text(
                                      Localizations.localeOf(context).languageCode == 'vi' ? 'TRÚNG GIẢI!' : 'WINNER!',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                // Prize level display
                                if (_prizeCategory != null) ...[
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFFFD966).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _getPrizeDisplayName(_prizeCategory!),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFFFD966),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                ],
                                // Win amount
                                Text(
                                  '${_winAmount.toString().replaceAllMapped(
                                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                    (Match m) => '${m[1]},',
                                  )} VND',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
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
                              child: FutureBuilder<File?>(
                                future: ImageStorageService.getTicketImage(_processedImagePath!),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: Center(
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    );
                                  }
                                  
                                  if (snapshot.hasData && snapshot.data != null) {
                                    return Image.file(
                                      snapshot.data!,
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
                                    );
                                  } else {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: Center(
                                        child: Icon(Icons.image_not_supported, color: Colors.grey[600], size: 20),
                                      ),
                                    );
                                  }
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
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color(0xFFFFD966).withOpacity(0.3), width: 1),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _buildSimpleField(AppLocalizations.of(context)!.province, city, Icons.location_on)),
                                  SizedBox(width: 8),
                                  Expanded(child: _buildSimpleField(AppLocalizations.of(context)!.date, date, Icons.calendar_today)),
                                ],
                              ),
                              SizedBox(height: 8),
                              _buildSimpleFieldWithHighlight(AppLocalizations.of(context)!.ticketNumber, ticketNumber, Icons.confirmation_number),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Quantity selector (full width like verification box)
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color(0xFFFFD966).withOpacity(0.3), width: 1),
                          ),
                          child: Column(
                            children: [
                              Text(
                                AppLocalizations.of(context)!.quantity,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFFFD966).withOpacity(0.8),
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
                                        color: _ticketQuantity > 1 ? Color(0xFFFFD966) : Colors.grey[600],
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(Icons.remove, color: _ticketQuantity > 1 ? Colors.black87 : Colors.white, size: 16),
                                    ),
                                  ),
                                  Text(
                                    '$_ticketQuantity',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
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
                                        color: _ticketQuantity < 99 ? Color(0xFFFFD966) : Colors.grey[600],
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(Icons.add, color: _ticketQuantity < 99 ? Colors.black87 : Colors.white, size: 16),
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
                                  backgroundColor: Color(0xFFFFD966),
                                  foregroundColor: Colors.black87,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.scanAnother,
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
                                  backgroundColor: Colors.white.withOpacity(0.06),
                                  foregroundColor: Colors.white,
                                  side: BorderSide(color: Color(0xFFFFD966).withOpacity(0.3)),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.done,
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

      // Require stored ticketId from DB storage
      if (_storedTicketId == null) {
        print('❌ Winner check aborted - no stored ticketId');
        setState(() {
          _isCheckingWinner = false;
          _winnerCheckError = 'Ticket not stored yet (no ticketId)';
        });
        return;
      }
      final payload = {
        'ticketId': _storedTicketId,
      };
      
      print('🎯 Checking winner with ticketId: $_storedTicketId');
      
      // Make direct API call (no authentication needed)
      final apiPath = AppConfig.isProduction ? '/prod/checkTicket' : '/dev/checkTicket';
      final apiUrl = '${AppConfig.apiGatewayBaseUrl}$apiPath';
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      
      print('🎯 Winner check response: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Check if this is a pending response
          final isPending = responseData['isPending'] as bool? ?? false;
          
          if (isPending) {
            print('⏳ Ticket is pending - results not yet available');
            setState(() {
              _isWinner = null; // Use null to indicate pending
              _winAmount = null;
              _prizeCategory = null;
              _matchedTiers = null;
              _isCheckingWinner = false;
              _winnerCheckError = responseData['message'] ?? 'Results not yet available';
            });
          } else {
            // Normal winner/not winner response
            final isWinner = (responseData['isWinner'] as bool?) ?? false;
            final winAmount = (responseData['winAmount'] as num?)?.toInt();
            final prizeCategory = responseData['prizeCategory'] as String?;
            
            setState(() {
              _isWinner = isWinner;
              _winAmount = winAmount;
              _prizeCategory = prizeCategory;
              _matchedTiers = prizeCategory != null ? [prizeCategory] : null;
              _isCheckingWinner = false;
            });
            
            if (isWinner) {
              print('🎉 WINNER! Amount: $_winAmount, Prize: $prizeCategory');
            } else {
              print('❌ Not a winner');
            }
          }
        } else {
          setState(() {
            _isCheckingWinner = false;
            _winnerCheckError = responseData['error']?.toString() ?? 'Unknown error';
          });
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
    // Vibrate with a strong impact for winning tickets
    HapticFeedback.heavyImpact();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Color(0xFFFFD966), width: 1.5),
          ),
          title: Row(
            children: [
              Icon(Icons.celebration, color: Color(0xFFFFD966), size: 30),
              SizedBox(width: 10),
              Text(
                Localizations.localeOf(context).languageCode == 'vi' ? 'Chúc Mừng!' : 'Congratulations!',
                style: TextStyle(
                  color: Color(0xFFFFD966),
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
                Localizations.localeOf(context).languageCode == 'vi' ? 'Vé của bạn TRÚNG GIẢI!' : 'Your ticket is a WINNER!',
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
                    '${Localizations.localeOf(context).languageCode == 'vi' ? 'Giải thưởng: ' : 'Prize: '}${winAmount.toString().replaceAllMapped(
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
                  '${Localizations.localeOf(context).languageCode == 'vi' ? 'Trúng: ' : 'Matched: '}${matchedTiers.join(', ')}',
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
                AppLocalizations.of(context)!.amazing,
                style: TextStyle(
                  color: Color(0xFFFFD966),
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
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Color(0xFFFFD966).withOpacity(0.2),
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
                color: Color(0xFFFFD966),
                size: 16,
              ),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFFFD966).withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                isFound ? Icons.check_circle : Icons.cancel,
                color: isFound ? Color(0xFFFFD966) : Colors.red.shade300,
                size: 14,
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: isFound ? Colors.white : Colors.red.shade300,
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

  /// Get localized prize display name from prize category
  String _getPrizeDisplayName(String prizeCategory) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) {
      return _getPrizeDisplayNameEnglish(prizeCategory);
    }
    
    final isVietnamese = Localizations.localeOf(context).languageCode == 'vi';
    return isVietnamese 
        ? _getPrizeDisplayNameVietnamese(prizeCategory)
        : _getPrizeDisplayNameEnglish(prizeCategory);
  }

  String _getPrizeDisplayNameEnglish(String prizeCategory) {
    switch (prizeCategory.toUpperCase()) {
      case 'DB':
      case 'ĐB':
        return 'Special Prize';
      case 'G1':
        return 'First Prize';
      case 'G2':
        return 'Second Prize';
      case 'G3':
        return 'Third Prize';
      case 'G4':
        return 'Fourth Prize';
      case 'G5':
        return 'Fifth Prize';
      case 'G6':
        return 'Sixth Prize';
      case 'G7':
        return 'Seventh Prize';
      case 'G8':
        return 'Eighth Prize';
      case 'PHU_DB':
        return 'Special Bonus';
      case 'KK':
        return 'Consolation Prize';
      default:
        return prizeCategory;
    }
  }

  String _getPrizeDisplayNameVietnamese(String prizeCategory) {
    switch (prizeCategory.toUpperCase()) {
      case 'DB':
      case 'ĐB':
        return 'Giải Đặc Biệt';
      case 'G1':
        return 'Giải Nhất';
      case 'G2':
        return 'Giải Nhì';
      case 'G3':
        return 'Giải Ba';
      case 'G4':
        return 'Giải Tư';
      case 'G5':
        return 'Giải Năm';
      case 'G6':
        return 'Giải Sáu';
      case 'G7':
        return 'Giải Bảy';
      case 'G8':
        return 'Giải Tám';
      case 'PHU_DB':
        return 'Phụ Đặc Biệt';
      case 'KK':
        return 'Khuyến Khích';
      default:
        return prizeCategory;
    }
  }

  /// Get number of matching digits based on prize category
  int _getMatchingDigitsCount(String prizeCategory) {
    switch (prizeCategory.toUpperCase()) {
      case 'DB':
      case 'ĐB':
        return 6; // Full number match for Special Prize
      case 'G1':
      case 'G2':
      case 'G3':
      case 'G4':
        return 5; // Last 5 digits
      case 'G5':
      case 'G6':
        return 4; // Last 4 digits
      case 'G7':
        return 3; // Last 3 digits
      case 'G8':
        return 2; // Last 2 digits
      case 'PHU_DB':
        return 5; // Last 5 digits match (special bonus)
      case 'KK':
        return 6; // All digits but one different (Hamming distance 1)
      default:
        return 0;
    }
  }

  /// Build highlighted ticket number with gold matching digits
  Widget _buildHighlightedTicketNumber(String ticketNum) {
    if (_isWinner != true || _prizeCategory == null || ticketNum == 'Not found') {
      return Text(
        ticketNum,
        style: TextStyle(
          fontSize: 13,
          color: ticketNum != 'Not found' ? Colors.white : Colors.red.shade300,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final matchingDigits = _getMatchingDigitsCount(_prizeCategory!);
    if (matchingDigits <= 0 || matchingDigits > ticketNum.length) {
      return Text(
        ticketNum,
        style: TextStyle(
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Split the ticket number into non-matching and matching parts
    final nonMatchingPart = ticketNum.substring(0, ticketNum.length - matchingDigits);
    final matchingPart = ticketNum.substring(ticketNum.length - matchingDigits);

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          if (nonMatchingPart.isNotEmpty)
            TextSpan(
              text: nonMatchingPart,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          TextSpan(
            text: matchingPart,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFFFD966), // Gold color for matching digits
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Build simple field for clean grid layout (modified for ticket number highlighting)
  Widget _buildSimpleFieldWithHighlight(String label, String value, IconData icon) {
    final isFound = value != 'Not found';
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Color(0xFFFFD966).withOpacity(0.2),
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
                color: Color(0xFFFFD966),
                size: 16,
              ),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFFFD966).withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                isFound ? Icons.check_circle : Icons.cancel,
                color: isFound ? Color(0xFFFFD966) : Colors.red.shade300,
                size: 14,
              ),
            ],
          ),
          SizedBox(height: 4),
          _buildHighlightedTicketNumber(value),
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
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFFFFD966).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFFFFD966), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFFD966).withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: isFound ? Colors.white : Colors.red.shade300,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isFound 
                ? Color(0xFFFFD966).withOpacity(0.2) 
                : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isFound ? 'Found' : 'Missing',
              style: TextStyle(
                color: isFound ? Color(0xFFFFD966) : Colors.red.shade300,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Process manual entry data (similar to background processing but for manual input)
  Future<void> _processManualEntry() async {
    try {
      print('🎯 Processing manual entry data...');
      
      // For manual entry, we use the sample image from assets
      String? savedImagePath;
      
      // Load and save the sample image
      try {
        final ByteData imageData = await rootBundle.load('assets/images/Sample Images/IMG_2308.jpg');
        final Uint8List imageBytes = imageData.buffer.asUint8List();
        
        savedImagePath = await ImageStorageService.saveTicketImage(
          imageBytes: imageBytes,
          ticketId: '${ticketNumber}_${DateTime.now().millisecondsSinceEpoch}',
        );
        
        if (savedImagePath != null) {
          print('✅ Sample image saved for manual entry: $savedImagePath');
          setState(() {
            _processedImagePath = savedImagePath;
          });
        }
      } catch (e) {
        print('⚠️ Could not load sample image for manual entry: $e');
        // Continue without image
      }
      
      // Convert manual city to proper Vietnamese name for API/DB storage
      final String provinceForApi = _getProvinceInVietnamese(city);
      final String apiDate = TicketStorageService.convertDateToApiFormat(date);
      final region = TicketStorageService.getRegionForCity(provinceForApi, _citiesData);
      
      if (region != null) {
        print('📤 MANUAL ENTRY DB STORAGE: Storing ticket with imagePath: $savedImagePath');
        print('=== MANUAL ENTRY DB STORAGE PAYLOAD ===');
        print('ticketNumber: $ticketNumber');
        print('province: $provinceForApi');
        print('drawDate: $apiDate');
        print('region: $region');
        print('ocrRawText: $rawText');
        print('imagePath: $savedImagePath');
        print('========================');
        
        final storedTicketId = await TicketStorageService.storeTicket(
          ticketNumber: ticketNumber,
          province: provinceForApi,
          drawDate: apiDate,
          region: region,
          ocrRawText: rawText,
          imagePath: savedImagePath,
        );
        
        print('🔄 MANUAL ENTRY DB STORAGE RESULT: ${storedTicketId != null ? "SUCCESS" : "FAILED"}');
        
        // Check for winners after successful storage
        if (storedTicketId != null) {
          // Store the ticket ID for duplication
          _storedTicketId = storedTicketId;
          
          print('🎯 Checking for winners (manual entry)...');
          await _checkTicketWinner(ticketNumber, provinceForApi, apiDate);
          
          print('💾 Stored ticket ID for potential duplication: $storedTicketId');
          print('🔢 Current total quantity selected: $_ticketQuantity');
          
          // Upload sample image to S3 in background
          _uploadManualEntryToS3(ticketNumber, city, date, savedImagePath);
        }
      } else {
        print('❌ No region found for province: $provinceForApi');
        setState(() {
          _winnerCheckError = 'Cannot determine region for $provinceForApi';
        });
      }
    } catch (e) {
      print('❌ Error in manual entry processing: $e');
      setState(() {
        _winnerCheckError = 'Manual entry processing error: $e';
      });
    }
  }

  /// Upload sample image to S3 for manual entry
  void _uploadManualEntryToS3(String ticketResult, String cityResult, String dateResult, String? localImagePath) {
    if (localImagePath == null) {
      print('🚀 S3: No image to upload for manual entry');
      return;
    }
    
    Future.delayed(Duration(milliseconds: 100), () async {
      try {
        print('🚀 S3: Starting manual entry upload after processing complete');
        print('🚀 S3: Ticket: $ticketResult, Province: $cityResult, Date: $dateResult');
        
        final imageFile = File(localImagePath);
        if (await imageFile.exists()) {
          final imageBytes = await imageFile.readAsBytes();
          print('✅ Saved ticket image locally: ${imageFile.path.split('/').last} (${(imageBytes.length / 1024).toStringAsFixed(1)} KB)');
          
          // Use S3UploadService for the upload
          await S3UploadService.uploadTicketImage(
            imageBytes: imageBytes,
            ticketNumber: ticketResult,
            province: cityResult,
            date: dateResult,
          );
        }
      } catch (e) {
        print('❌ Manual entry S3 upload error: $e');
      }
    });
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
          
          // Save locally first (fast)
          savedImagePath = await ImageStorageService.saveTicketImage(
            imageBytes: imageBytes,
            ticketId: '${ticketResult}_${DateTime.now().millisecondsSinceEpoch}',
          );
          
          // S3 upload will be triggered after winner check is complete
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
          
          // Now upload to S3 in background (after all processing is complete)
          _uploadToS3InBackground(voted, ticketResult, cityResult, dateResult);
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

  /// Upload image to S3 in background after all processing is complete
  void _uploadToS3InBackground(
    Map<String, dynamic> voted,
    String ticketResult,
    String cityResult,
    String dateResult,
  ) {
    final tempImagePath = voted['imagePath'] ?? '';
    if (tempImagePath.isEmpty) {
      print('❌ S3: No image path available for upload');
      return;
    }

    print('🚀 S3: Starting background upload after all processing complete');
    print('🚀 S3: Ticket: $ticketResult, Province: $cityResult, Date: $dateResult');

    // Upload to S3 in background (don't await it)
    File(tempImagePath).readAsBytes().then((imageBytes) {
      return ImageStorageService.saveTicketImageWithS3(
        imageBytes: imageBytes,
        ticketNumber: ticketResult,
        province: cityResult,
        date: dateResult,
      );
    }).then((saveResult) {
      final s3Url = saveResult['s3Url'];
      if (s3Url != null) {
        print('✅ S3: Background upload successful: $s3Url');
      } else {
        print('❌ S3: Background upload failed - no URL returned');
      }
    }).catchError((error) {
      print('❌ S3: Background upload error: $error');
    });
  }

  /// Get the header text based on winner status
  String _getHeaderText() {
    if (_isWinner == true) {
      return AppLocalizations.of(context)!.winner;
    } else if (_isWinner == false) {
      return AppLocalizations.of(context)!.notWinner;
    } else if (_winnerCheckError != null && 
               (_winnerCheckError!.contains('not available yet') || 
                _winnerCheckError!.contains('Results not available yet') ||
                _winnerCheckError!.contains('404'))) {
      return AppLocalizations.of(context)!.resultsPending;
    } else {
      return AppLocalizations.of(context)!.scanComplete;
    }
  }

  /// Get the header color based on winner status
  Color _getHeaderColor() {
    if (_isWinner == true) {
      return Color(0xFFFFD966); // Gold for winners
    } else if (_isWinner == false) {
      return Colors.red.shade300; // Light red for not a winner
    } else if (_winnerCheckError != null && 
               (_winnerCheckError!.contains('not available yet') || 
                _winnerCheckError!.contains('Results not available yet') ||
                _winnerCheckError!.contains('404'))) {
      return Colors.orange.shade300; // Orange for pending results
    } else {
      return Color(0xFFFFD966); // Gold for scan complete
    }
  }

  /// Handle camera tap for smart focus (like native camera app)
  Future<void> _handleCameraTap(TapUpDetails details) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    // Stop auto-scanning temporarily
    final wasAutoScanning = _isAutoScanning;
    if (_isAutoScanning) {
      print('📷 Stopping auto-scan for manual focus');
      _stopAutoScanning();
    }

    try {
      final renderBox = context.findRenderObject() as RenderBox;
      final tapPosition = renderBox.globalToLocal(details.globalPosition);
      final previewSize = renderBox.size;
      
      // Convert tap position to camera coordinates
      final x = tapPosition.dx / previewSize.width;
      final y = tapPosition.dy / previewSize.height;
      
      print('📷 User tapped at ($x, $y) for manual focus');
      
      // Show focus indicator at tap position
      setState(() {
        _focusIndicatorPosition = tapPosition;
        _showFocusIndicator = true;
      });
      
      // Cancel any existing focus timer
      _focusIndicatorTimer?.cancel();
      
      // Set focus and exposure to tap point
      await _cameraController!.setFocusPoint(Offset(x, y));
      await _cameraController!.setExposurePoint(Offset(x, y));
      
      // Hide focus indicator after 1.5 seconds (like native camera)
      _focusIndicatorTimer = Timer(Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _showFocusIndicator = false;
          });
        }
      });
      
      // Restart auto-scanning after focus settles if it was running
      if (wasAutoScanning && !_showingResults) {
        print('📷 Restarting auto-scan with new focus');
        Future.delayed(Duration(milliseconds: 800), () {
          if (mounted && !_showingResults && !_isAutoScanning) {
            _startAutoScanning();
          }
        });
      }
      
    } catch (e) {
      print('⚠️ Focus/exposure setting failed: $e');
    }
  }



  /// Add results to rolling window and update best stacked results
  void _updateRollingResults(String cityResult, String dateResult, String ticketResult) {
    _currentFrameNumber++;
    
    // Add current frame results
    _rollingResults.add({
      'city': cityResult,
      'date': dateResult,
      'ticketNumber': ticketResult,
      'frameNumber': _currentFrameNumber.toString()
    });
    
    // Remove old results outside the rolling window
    while (_rollingResults.length > _rollingWindowSize) {
      _rollingResults.removeAt(0);
    }
    
    print('🎞️ Rolling window: ${_rollingResults.length}/$_rollingWindowSize frames');
    
    // Find best results from rolling window
    _bestStackedResults = {
      'city': 'Not found',
      'date': 'Not found',
      'ticketNumber': 'Not found'
    };
    
    // Look for the most recent valid result for each field
    for (int i = _rollingResults.length - 1; i >= 0; i--) {
      final result = _rollingResults[i];
      
      if (_bestStackedResults['city'] == 'Not found' && result['city'] != 'Not found') {
        _bestStackedResults['city'] = result['city']!;
        print('📍 Found CITY in frame ${result['frameNumber']}: ${result['city']}');
      }
      
      if (_bestStackedResults['date'] == 'Not found' && result['date'] != 'Not found') {
        _bestStackedResults['date'] = result['date']!;
        print('📅 Found DATE in frame ${result['frameNumber']}: ${result['date']}');
      }
      
      if (_bestStackedResults['ticketNumber'] == 'Not found' && result['ticketNumber'] != 'Not found') {
        _bestStackedResults['ticketNumber'] = result['ticketNumber']!;
        print('🎫 Found TICKET in frame ${result['frameNumber']}: ${result['ticketNumber']}');
      }
    }
    
    // Count how many fields we have
    final stackedCount = _bestStackedResults.values.where((v) => v != 'Not found').length;
    print('🎯 Rolling stacked: $stackedCount/3 fields across ${_rollingResults.length} frames');
  }

  // Old manual duplication method removed - now using Lambda function
}
