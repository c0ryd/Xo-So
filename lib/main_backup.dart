import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';  // Temporarily disabled
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/intl.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';

late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize timezone data
  tz.initializeTimeZones();
  
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
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show loading screen while checking auth state
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasData) {
          // User is signed in, show main app
          return MainAppScreen();
        } else {
          // User is not signed in, show login screen
          return LoginScreen();
        }
      },
    );
  }
}

class MainAppScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vietnamese Lottery OCR'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'profile') {
                _showProfileDialog(context);
              } else if (value == 'logout') {
                await AuthService().signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: LotteryOCRScreen(),
    );
  }

  void _showProfileDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user?.displayName != null) ...[
              Text('Name: ${user!.displayName}'),
              const SizedBox(height: 8),
            ],
            if (user?.email != null) ...[
              Text('Email: ${user!.email}'),
              const SizedBox(height: 8),
            ],
            if (user?.phoneNumber != null) ...[
              Text('Phone: ${user!.phoneNumber}'),
              const SizedBox(height: 8),
            ],
            Text('Account created: ${user?.metadata.creationTime?.toString().split(' ')[0] ?? 'Unknown'}'),
            const SizedBox(height: 12),
            Text(
              'Provider: ${user?.providerData.map((p) => p.providerId).join(', ') ?? 'Unknown'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
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
  
  // Winner checking state
  bool _isCheckingWinner = false;
  bool? _isWinner;
  int? _winAmount;
  List<String>? _matchedTiers;
  String? _winnerCheckError;
  
  // Auto-scanning state
  bool _isAutoScanning = false;
  int _autoScanAttempts = 0;
  static const int _maxAutoScanAttempts = 20; // Stop after 20 attempts
  Timer? _autoScanTimer;
  
  // AWS configuration
  static const String identityPoolId = 'us-east-1:1760d4fe-571e-483d-8575-ab98071244ca';
  static const String awsRegion = 'us-east-1';
  static const String lambdaRegion = 'ap-southeast-1';

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
    _autoScanTimer?.cancel();
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
        
        // Reset winner checking state
        _isWinner = null;
        _winAmount = null;
        _matchedTiers = null;
        _winnerCheckError = null;
      });
      
      // Check if we should call the winner checking API
      if (city != 'Not found' && date != 'Not found' && ticketNumber != 'Not found') {
        await _checkWinnerIfEligible();
      }
      
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
  
  // Check if ticket should be checked for winning (date/time logic)
  Future<void> _checkWinnerIfEligible() async {
    if (!_shouldCheckWinner()) {
      print('Ticket not eligible for winner checking yet');
      return;
    }
    
    await _checkWinner();
  }
  
  bool _shouldCheckWinner() {
    if (date == 'Not found') return false;
    
    try {
      // Parse the ticket date (expected format: DD-MM-YYYY)
      final dateParts = date.split('-');
      if (dateParts.length != 3) return false;
      
      final ticketDate = DateTime(
        int.parse(dateParts[2]), // year
        int.parse(dateParts[1]), // month
        int.parse(dateParts[0])  // day
      );
      
      // Get current Vietnam time
      final vietnamLocation = tz.getLocation('Asia/Ho_Chi_Minh');
      final now = tz.TZDateTime.now(vietnamLocation);
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
  
  Future<CognitoCredentials> _getAwsCredentials() async {
    try {
      // Create a dummy user pool with properly formatted values for unauthenticated access
      // These values won't be used since we're not authenticating, but they need proper format
      final userPool = CognitoUserPool(
        'us-east-1_dummy12345', // Proper user pool ID format
        'dummy1234567890abcdef1234567890' // Proper client ID format
      );
      
      // Create CognitoCredentials for unauthenticated access using Identity Pool
      final credentials = CognitoCredentials(identityPoolId, userPool);
      
      // Get AWS credentials for unauthenticated access (pass null for unauthenticated)
      await credentials.getAwsCredentials(null);
      
      print('=== DEBUG CREDENTIALS FOR LOCAL TESTING ===');
      print('Access Key: ${credentials.accessKeyId}');
      print('Secret Key: ${credentials.secretAccessKey}');
      print('Session Token (FULL): ${credentials.sessionToken}');
      print('============================');
      
      return credentials;
    } catch (e) {
      throw Exception('AWS authentication failed: $e');
    }
  }

  Future<void> _checkWinner() async {
    setState(() {
      _isCheckingWinner = true;
      _winnerCheckError = null;
    });
    
    try {
      final region = _getRegionForCity(city);
      if (region == null) {
        throw Exception('Cannot determine region for city: $city');
      }
      
      // Convert date to YYYY-MM-DD format for API
      final apiDate = _convertDateToApiFormat(date);
      if (apiDate == null) {
        throw Exception('Invalid date format: $date');
      }
      
      // Normalize province name (remove Vietnamese accents for API compatibility)
      final normalizedProvince = _normalizeProvinceForApi(city);
      print('Province normalized: "$city" -> "$normalizedProvince"');
      
      final payload = {
        'ticket': ticketNumber,
        'province': normalizedProvince,
        'date': apiDate,
        'region': region,
      };
      
      print('Calling winner API with payload: $payload');
      
      // Get AWS credentials using proper Cognito SDK
      final credentials = await _getAwsCredentials();
      
      // Using API Gateway HTTP API endpoint (base URL without the path)
      final apiGatewayUrl = 'https://nt1f2gqrh4.execute-api.ap-southeast-1.amazonaws.com/Production';
      
      final awsSigV4Client = AwsSigV4Client(
        credentials.accessKeyId!,
        credentials.secretAccessKey!,
        apiGatewayUrl,
        sessionToken: credentials.sessionToken!,
        region: lambdaRegion,
      );
      
      // Create signed request using the AWS SDK (designed for API Gateway)
      final signedRequest = SigV4Request(
        awsSigV4Client,
        method: 'POST',
        path: '/check_results',
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );
      
      print('Making signed request to: ${signedRequest.url}');
      print('Request body: ${signedRequest.body}');
      print('Request headers: ${signedRequest.headers}');
      
      // Make the authenticated HTTP request
      final response = await http.post(
        Uri.parse(signedRequest.url!),
        headers: signedRequest.headers?.cast<String, String>(),
        body: signedRequest.body,
      );
      
      print('Winner API response: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        // API Gateway returns the Lambda response body directly, not wrapped
        final responseData = json.decode(response.body);
        
        setState(() {
          _isWinner = responseData['Winner'] as bool;
          _winAmount = responseData['Sum'] as int?;
          _matchedTiers = (responseData['MatchedTiers'] as List?)?.cast<String>();
          _isCheckingWinner = false;
        });
      } else {
        throw Exception('API returned ${response.statusCode}: ${response.body}');
      }
      
    } catch (e) {
      print('Error checking winner: $e');
      setState(() {
        _winnerCheckError = e.toString();
        _isCheckingWinner = false;
      });
    }
  }
  
  String? _getRegionForCity(String cityName) {
    if (_citiesData.isEmpty) return null;
    
    for (final region in _citiesData['regions']) {
      final cities = region['cities'] as List;
      if (cities.contains(cityName)) {
        final englishName = region['english_name'] as String;
        // Convert to the format expected by the API
        switch (englishName.toLowerCase()) {
          case 'northern':
            return 'north';
          case 'central':
            return 'central';
          case 'southern':
            return 'south';
          default:
            return englishName.toLowerCase();
        }
      }
    }
    
    // Fallback for special cases
    if (cityName.contains('Hồ Chí Minh') || cityName.contains('TP.')) {
      return 'south';
    }
    
    return null;
  }
  
  String? _convertDateToApiFormat(String dateStr) {
    try {
      // Convert DD-MM-YYYY to YYYY-MM-DD
      final parts = dateStr.split('-');
      if (parts.length != 3) return null;
      
      return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    } catch (e) {
      return null;
    }
  }

  // Remove Vietnamese accents and prefixes for API compatibility
  String _normalizeProvinceForApi(String province) {
    // First remove Vietnamese accents
    String normalized = province
        .replaceAll('ấ', 'a').replaceAll('ầ', 'a').replaceAll('ẩ', 'a')
        .replaceAll('ẫ', 'a').replaceAll('ậ', 'a').replaceAll('á', 'a')
        .replaceAll('à', 'a').replaceAll('ả', 'a').replaceAll('ã', 'a')
        .replaceAll('ạ', 'a').replaceAll('â', 'a').replaceAll('ă', 'a')
        .replaceAll('ắ', 'a').replaceAll('ằ', 'a').replaceAll('ẳ', 'a')
        .replaceAll('ẵ', 'a').replaceAll('ặ', 'a')
        .replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ẻ', 'e')
        .replaceAll('ẽ', 'e').replaceAll('ẹ', 'e').replaceAll('ê', 'e')
        .replaceAll('ế', 'e').replaceAll('ề', 'e').replaceAll('ể', 'e')
        .replaceAll('ễ', 'e').replaceAll('ệ', 'e')
        .replaceAll('í', 'i').replaceAll('ì', 'i').replaceAll('ỉ', 'i')
        .replaceAll('ĩ', 'i').replaceAll('ị', 'i')
        .replaceAll('ó', 'o').replaceAll('ò', 'o').replaceAll('ỏ', 'o')
        .replaceAll('õ', 'o').replaceAll('ọ', 'o').replaceAll('ô', 'o')
        .replaceAll('ố', 'o').replaceAll('ồ', 'o').replaceAll('ổ', 'o')
        .replaceAll('ỗ', 'o').replaceAll('ộ', 'o').replaceAll('ơ', 'o')
        .replaceAll('ớ', 'o').replaceAll('ờ', 'o').replaceAll('ở', 'o')
        .replaceAll('ỡ', 'o').replaceAll('ợ', 'o')
        .replaceAll('ú', 'u').replaceAll('ù', 'u').replaceAll('ủ', 'u')
        .replaceAll('ũ', 'u').replaceAll('ụ', 'u').replaceAll('ư', 'u')
        .replaceAll('ứ', 'u').replaceAll('ừ', 'u').replaceAll('ử', 'u')
        .replaceAll('ữ', 'u').replaceAll('ự', 'u')
        .replaceAll('ý', 'y').replaceAll('ỳ', 'y').replaceAll('ỷ', 'y')
        .replaceAll('ỹ', 'y').replaceAll('ỵ', 'y')
        .replaceAll('đ', 'd').replaceAll('Đ', 'D')
        // Uppercase versions
        .replaceAll('Ấ', 'A').replaceAll('Ầ', 'A').replaceAll('Ẩ', 'A')
        .replaceAll('Ẫ', 'A').replaceAll('Ậ', 'A').replaceAll('Á', 'A')
        .replaceAll('À', 'A').replaceAll('Ả', 'A').replaceAll('Ã', 'A')
        .replaceAll('Ạ', 'A').replaceAll('Â', 'A').replaceAll('Ă', 'A')
        .replaceAll('Ắ', 'A').replaceAll('Ằ', 'A').replaceAll('Ẳ', 'A')
        .replaceAll('Ẵ', 'A').replaceAll('Ặ', 'A')
        .replaceAll('É', 'E').replaceAll('È', 'E').replaceAll('Ẻ', 'E')
        .replaceAll('Ẽ', 'E').replaceAll('Ẹ', 'E').replaceAll('Ê', 'E')
        .replaceAll('Ế', 'E').replaceAll('Ề', 'E').replaceAll('Ể', 'E')
        .replaceAll('Ễ', 'E').replaceAll('Ệ', 'E')
        .replaceAll('Í', 'I').replaceAll('Ì', 'I').replaceAll('Ỉ', 'I')
        .replaceAll('Ĩ', 'I').replaceAll('Ị', 'I')
        .replaceAll('Ó', 'O').replaceAll('Ò', 'O').replaceAll('Ỏ', 'O')
        .replaceAll('Õ', 'O').replaceAll('Ọ', 'O').replaceAll('Ô', 'O')
        .replaceAll('Ố', 'O').replaceAll('Ồ', 'O').replaceAll('Ổ', 'O')
        .replaceAll('Ỗ', 'O').replaceAll('Ộ', 'O').replaceAll('Ơ', 'O')
        .replaceAll('Ớ', 'O').replaceAll('Ờ', 'O').replaceAll('Ở', 'O')
        .replaceAll('Ỡ', 'O').replaceAll('Ợ', 'O')
        .replaceAll('Ú', 'U').replaceAll('Ù', 'U').replaceAll('Ủ', 'U')
        .replaceAll('Ũ', 'U').replaceAll('Ụ', 'U').replaceAll('Ư', 'U')
        .replaceAll('Ứ', 'U').replaceAll('Ừ', 'U').replaceAll('Ử', 'U')
        .replaceAll('Ữ', 'U').replaceAll('Ự', 'U')
        .replaceAll('Ý', 'Y').replaceAll('Ỳ', 'Y').replaceAll('Ỷ', 'Y')
        .replaceAll('Ỹ', 'Y').replaceAll('Ỵ', 'Y');
    
    // Remove common city prefixes to match exact database format
    normalized = normalized
        .replaceAll('TP. ', '')  // Thành phố (City)
        .replaceAll('Tp. ', '')
        .replaceAll('TP.', '')
        .replaceAll('Tp.', '')
        .replaceAll('T.P. ', '')
        .replaceAll('T.P.', '')
        .replaceAll('Thanh pho ', '')
        .replaceAll('Tinh ', '')  // Tỉnh (Province)
        .replaceAll('Tỉnh ', '')
        .trim();
    
    // Handle specific mappings to match exact database format
    final Map<String, String> exactMappings = {
      'Ho Chi Minh': 'Ho Chi Minh',
      'HCM': 'Ho Chi Minh',
      'Sai Gon': 'Ho Chi Minh',
      'Thu Duc': 'Ho Chi Minh',
      'Da Lat': 'Da Lat',
      'Dalat': 'Da Lat',
      'Ha Noi': 'Hanoi',
      'Hanoi': 'Hanoi',
      'Can Tho': 'Can Tho',
      'Cantho': 'Can Tho',
      'Da Nang': 'Da Nang',
      'Danang': 'Da Nang',
    };
    
    // Check for exact mappings first
    for (final entry in exactMappings.entries) {
      if (normalized.toLowerCase() == entry.key.toLowerCase()) {
        return entry.value;
      }
    }
    
    return normalized;
  }


  // Check if any critical values are missing
  bool _hasMissingValues() {
    return city == 'Not found' || date == 'Not found' || ticketNumber == 'Not found';
  }

  // Get text showing which fields have been found during auto-scanning
  String _getFoundFieldsText() {
    List<String> found = [];
    if (city != 'Not found') found.add('City');
    if (date != 'Not found') found.add('Date'); 
    if (ticketNumber != 'Not found') found.add('Ticket#');
    
    if (found.isEmpty) {
      return 'Searching for City, Date, and Ticket Number...';
    } else if (found.length == 3) {
      return 'All fields found! ✓';
    } else {
      return '${found.join(', ')} ✓ (need ${3 - found.length} more)';
    }
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
      
      // Reset auto-scanning state
      _isAutoScanning = false;
      _autoScanAttempts = 0;
      _isWinner = null;
      _winAmount = null;
      _matchedTiers = null;
      _winnerCheckError = null;
    });
    
    // Cancel any existing auto-scan timer
    _autoScanTimer?.cancel();
    
    // Directly open camera and start auto-scanning
    await _initializeCamera();
    
    // Wait a moment for camera to stabilize, then start auto-scanning
    await Future.delayed(Duration(milliseconds: 500));
    _startAutoScanning();
  }

  // Start automatic scanning until all values are found
  void _startAutoScanning() {
    if (_isAutoScanning) return; // Already running
    
    setState(() {
      _isAutoScanning = true;
      _autoScanAttempts = 0;
    });
    
    print('=== AUTO-SCANNING STARTED ===');
    _performAutoScan();
  }
  
  // Stop automatic scanning
  void _stopAutoScanning() {
    _autoScanTimer?.cancel();
    setState(() {
      _isAutoScanning = false;
    });
    print('=== AUTO-SCANNING STOPPED ===');
  }
  
  // Perform a single auto-scan attempt
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
      // Take a single picture
      final XFile picture = await _cameraController!.takePicture();
      
      // Process the image
      final result = await _processSingleImage(picture);
      if (result != null) {
        // Extract data directly from the result (no nested 'parsedInfo')
        final cityResult = result['city'] as String;
        final dateResult = result['date'] as String;
        final ticketResult = result['ticketNumber'] as String;
        final confidence = result['confidence'] as double;
        
        // Check if we have good results - be less strict to avoid infinite scanning
        bool hasGoodCity = cityResult != 'Not found';
        bool hasGoodDate = dateResult != 'Not found';  
        bool hasGoodTicket = ticketResult != 'Not found';
        int foundCount = (hasGoodCity ? 1 : 0) + (hasGoodDate ? 1 : 0) + (hasGoodTicket ? 1 : 0);
        
        print('Auto-scan confidence: $confidence - City: $cityResult, Date: $dateResult, Ticket: $ticketResult');
        print('Found: ${foundCount}/3 fields (need all 3 to stop)');
        print('Raw OCR text: ${result['rawText']}');
        
        // Only stop when ALL THREE fields are found
        if (foundCount == 3) {
          
          // We found confident results - stop auto-scanning and update UI
          print('=== AUTO-SCAN SUCCESS! Found $foundCount/3 fields ===');
          _stopAutoScanning();
          
          setState(() {
            city = cityResult;
            date = dateResult;
            ticketNumber = ticketResult;
            rawText = result['rawText'] ?? '';
            _processedImagePath = result['imagePath'] ?? '';
            isProcessing = false;
            _isCameraInitialized = false;
          });
          
          // Close camera
          _cameraController?.dispose();
          _cameraController = null;
          
          // Check winner if we have all required info
          await _checkWinnerIfEligible();
          
          return;
        }
      } else {
        print('Auto-scan: Failed to process image, continuing...');
      }
      
      // Schedule next scan if we haven't found confident results
      if (_isAutoScanning && _autoScanAttempts < _maxAutoScanAttempts) {
        print('Scheduling next auto-scan in 2 seconds...');
        _autoScanTimer = Timer(Duration(milliseconds: 2000), () {
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
              
              // Auto-scanning status or manual controls
              if (_isAutoScanning) ...[
                // Auto-scanning status
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
              ] else ...[
                // Manual picture button (fallback)
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
                      isProcessing ? 'Processing...' : 'Take Picture (Manual)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ],
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
                        onPressed: isProcessing ? null : _scanAnother,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isProcessing ? 'Starting...' : 'Start Auto-Scan',
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
                      child: Text('Auto-Scan Another'),
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
                              // Reset winner checking state
                              _isWinner = null;
                              _winAmount = null;
                              _matchedTiers = null;
                              _winnerCheckError = null;
                            });
                            
                            // Check winner if all info is available
                            if (city != 'Not found' && date != 'Not found' && ticketNumber != 'Not found') {
                              await _checkWinnerIfEligible();
                            }
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
              
              // Winner checking results
              if (_isCheckingWinner) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Checking if ticket is a winner...',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ] else if (_isWinner != null) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isWinner! ? Colors.green[50] : Colors.grey[50],
                    border: Border.all(
                      color: _isWinner! ? Colors.green : Colors.grey,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isWinner! ? Icons.celebration : Icons.info,
                            color: _isWinner! ? Colors.green : Colors.grey,
                            size: 32,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isWinner! ? '🎉 WINNER! 🎉' : 'Not a Winner',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _isWinner! ? Colors.green : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_isWinner!) ...[
                        SizedBox(height: 12),
                        Text(
                          'Congratulations! You have won:',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(_winAmount)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        if (_matchedTiers != null && _matchedTiers!.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            'Matched Tiers: ${_matchedTiers!.join(', ')}',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ] else ...[
                        SizedBox(height: 8),
                        Text(
                          'This ticket did not match any winning numbers.',
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ] else if (_winnerCheckError != null) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Winner Check Failed',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        _winnerCheckError!,
                        style: TextStyle(fontSize: 14, color: Colors.red[700]),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ] else if (city != 'Not found' && date != 'Not found' && ticketNumber != 'Not found' && !_shouldCheckWinner()) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Winner checking will be available after the draw date or after 4:15 PM Vietnam time on the draw date.',
                          style: TextStyle(fontSize: 14, color: Colors.orange[700]),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],
              
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