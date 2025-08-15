import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import '../services/ticket_storage_service.dart';
import '../services/image_storage_service.dart';
import '../widgets/vietnamese_tiled_background.dart';

class ScanResultsScreen extends StatefulWidget {
  final String imagePath;
  final String? city;
  final String? date;
  final String? ticketNumber;
  final String? rawText;
  final bool alreadyStored;

  const ScanResultsScreen({
    Key? key,
    required this.imagePath,
    this.city,
    this.date,
    this.ticketNumber,
    this.rawText,
    this.alreadyStored = false,
  }) : super(key: key);

  @override
  State<ScanResultsScreen> createState() => _ScanResultsScreenState();
}

class _ScanResultsScreenState extends State<ScanResultsScreen> {
  // Working state
  bool _isStoring = false;
  bool _storeSuccess = false;
  bool _isCheckingWinner = false;
  String? _winnerCheckError;
  bool? _isWinner;
  int? _winAmount;
  List<String>? _matchedTiers;

  // Cities data
  Map<String, dynamic> _citiesData = {};
  List<String> _allCities = [];

  // Saved image path (permanent)
  String? _savedImagePath;

  // AWS config for winner check
  static const String _identityPoolId = 'ap-southeast-1:9728af83-62a8-410f-a585-53de188a5079';
  static const String _lambdaRegion = 'ap-southeast-1';
  static const String _apiGatewayUrl = 'https://u9maewv4ch.execute-api.ap-southeast-1.amazonaws.com/dev';

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _savedImagePath = widget.imagePath; // prefer provided path
    _loadCitiesData().then((_) => _processAndUpload());
  }

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
    } catch (e) {
      print('Error loading cities data: $e');
    }
  }

  Future<void> _processAndUpload() async {
    if (widget.city == null || widget.date == null || widget.ticketNumber == null) {
      return; // Missing fields, just display
    }

    // Ensure province uses Vietnamese characters to match DB storage
    final provinceForApi = _getProvinceInVietnamese(widget.city!);

    // Save image permanently unless it was already saved upstream
    if (!widget.alreadyStored) {
      try {
        final bytes = await File(widget.imagePath).readAsBytes();
        final saved = await ImageStorageService.saveTicketImage(
          imageBytes: bytes,
          ticketId: '${widget.ticketNumber}_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (mounted) {
          setState(() {
            _savedImagePath = saved ?? widget.imagePath;
          });
        }
      } catch (e) {
        print('Failed to save image permanently: $e');
        _savedImagePath = widget.imagePath;
      }
    }

    // Store ticket to backend unless already stored
    if (!widget.alreadyStored) {
      final region = TicketStorageService.getRegionForCity(provinceForApi, _citiesData);
      if (region != null) {
        setState(() => _isStoring = true);
        final apiDate = TicketStorageService.convertDateToApiFormat(widget.date!);
        final ticketId = await TicketStorageService.storeTicket(
          ticketNumber: widget.ticketNumber!,
          province: provinceForApi,
          drawDate: apiDate,
          region: region,
          ocrRawText: widget.rawText ?? '',
          imagePath: _savedImagePath,
        );
        if (mounted) {
          setState(() {
            _isStoring = false;
            _storeSuccess = ticketId != null;
          });
        }
      }
    } else {
      _storeSuccess = true;
    }

    // Check winner if eligible
    await _checkWinnerIfEligible();
  }

  bool _shouldCheckWinner() {
    if (widget.date == null) return false;
    try {
      final parts = widget.date!.split('-');
      if (parts.length != 3) return false;
      final ticketDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      final vnLoc = tz.getLocation('Asia/Ho_Chi_Minh');
      final now = tz.TZDateTime.now(vnLoc);
      final today = DateTime(now.year, now.month, now.day);
      if (ticketDate.isBefore(today)) return true;
      if (ticketDate.isAtSameMomentAs(today)) {
        final cutoff = DateTime(now.year, now.month, now.day, 16, 15);
        return now.isAfter(cutoff);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<CognitoCredentials> _getAwsCredentials() async {
    try {
      final userPool = CognitoUserPool('ap-southeast-1_dummy12345', 'dummy1234567890abcdef1234567890');
      final credentials = CognitoCredentials(_identityPoolId, userPool);
      await credentials.getAwsCredentials(null);
      return credentials;
    } catch (e) {
      throw Exception('AWS authentication failed: $e');
    }
  }

  Future<void> _checkWinnerIfEligible() async {
    if (!_shouldCheckWinner()) return;
    await _checkWinner();
  }

  Future<void> _checkWinner() async {
    if (widget.city == null || widget.date == null || widget.ticketNumber == null) return;
    setState(() {
      _isCheckingWinner = true;
      _winnerCheckError = null;
    });

    try {
      final provinceForApi = _getProvinceInVietnamese(widget.city!);
      final region = TicketStorageService.getRegionForCity(provinceForApi, _citiesData);
      if (region == null) throw Exception('Cannot determine region for city: ${widget.city}');
      final apiDate = TicketStorageService.convertDateToApiFormat(widget.date!);
      final payload = {
        'ticket': widget.ticketNumber,
        'province': provinceForApi,
        'date': apiDate,
        'region': region,
      };

      final credentials = await _getAwsCredentials();
      final awsSigV4Client = AwsSigV4Client(
        credentials.accessKeyId!,
        credentials.secretAccessKey!,
        _apiGatewayUrl,
        sessionToken: credentials.sessionToken!,
        region: _lambdaRegion,
      );

      final signed = SigV4Request(
        awsSigV4Client,
        method: 'POST',
        path: '/checkTicket',
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );

      final response = await http.post(
        Uri.parse(signed.url!),
        headers: signed.headers?.cast<String, String>(),
        body: signed.body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isWinner = data['Winner'] as bool;
          _winAmount = data['Sum'] as int?;
          _matchedTiers = (data['MatchedTiers'] as List?)?.cast<String>();
          _isCheckingWinner = false;
        });
        if (_isWinner == true) {
          _showWinnerPopup();
        }
      } else {
        throw Exception('API ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _winnerCheckError = e.toString();
        _isCheckingWinner = false;
      });
    }
  }

  // Map input (possibly non-diacritic) to official Vietnamese province from cities.json
  String _getProvinceInVietnamese(String input) {
    if (_allCities.isEmpty) return input; // Fallback
    // Exact match
    if (_allCities.contains(input)) return input;
    final normalizedInput = _normalizeForCompare(input);
    String best = input;
    double bestScore = 0.0;
    for (final city in _allCities) {
      if (city == null) continue;
      final normalizedCity = _normalizeForCompare(city);
      final score = _similarity(normalizedInput, normalizedCity);
      if (score > bestScore) {
        bestScore = score;
        best = city;
      }
      if (normalizedCity == normalizedInput) {
        return city; // perfect normalized match
      }
    }
    return best;
  }

  String _normalizeForCompare(String s) {
    return s
        .toUpperCase()
        .replaceAll('À', 'A').replaceAll('Á', 'A').replaceAll('Ả', 'A').replaceAll('Ã', 'A').replaceAll('Ạ', 'A')
        .replaceAll('Ă', 'A').replaceAll('Ằ', 'A').replaceAll('Ắ', 'A').replaceAll('Ẳ', 'A').replaceAll('Ẵ', 'A').replaceAll('Ặ', 'A')
        .replaceAll('Â', 'A').replaceAll('Ầ', 'A').replaceAll('Ấ', 'A').replaceAll('Ẩ', 'A').replaceAll('Ẫ', 'A').replaceAll('Ậ', 'A')
        .replaceAll('È', 'E').replaceAll('É', 'E').replaceAll('Ẻ', 'E').replaceAll('Ẽ', 'E').replaceAll('Ẹ', 'E')
        .replaceAll('Ê', 'E').replaceAll('Ề', 'E').replaceAll('Ế', 'E').replaceAll('Ể', 'E').replaceAll('Ễ', 'E').replaceAll('Ệ', 'E')
        .replaceAll('Ì', 'I').replaceAll('Í', 'I').replaceAll('Ỉ', 'I').replaceAll('Ĩ', 'I').replaceAll('Ị', 'I')
        .replaceAll('Ò', 'O').replaceAll('Ó', 'O').replaceAll('Ỏ', 'O').replaceAll('Õ', 'O').replaceAll('Ọ', 'O')
        .replaceAll('Ô', 'O').replaceAll('Ồ', 'O').replaceAll('Ố', 'O').replaceAll('Ổ', 'O').replaceAll('Ỗ', 'O').replaceAll('Ộ', 'O')
        .replaceAll('Ơ', 'O').replaceAll('Ờ', 'O').replaceAll('Ớ', 'O').replaceAll('Ở', 'O').replaceAll('Ỡ', 'O').replaceAll('Ợ', 'O')
        .replaceAll('Ù', 'U').replaceAll('Ú', 'U').replaceAll('Ủ', 'U').replaceAll('Ũ', 'U').replaceAll('Ụ', 'U')
        .replaceAll('Ư', 'U').replaceAll('Ừ', 'U').replaceAll('Ứ', 'U').replaceAll('Ử', 'U').replaceAll('Ữ', 'U').replaceAll('Ự', 'U')
        .replaceAll('Ỳ', 'Y').replaceAll('Ý', 'Y').replaceAll('Ỷ', 'Y').replaceAll('Ỹ', 'Y').replaceAll('Ỵ', 'Y')
        .replaceAll('Đ', 'D')
        .replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;
    // simple ratio based on longest common subsequence approximation via common char count
    final setA = a.split('').toSet();
    final setB = b.split('').toSet();
    final intersection = setA.intersection(setB).length.toDouble();
    final union = setA.union(setB).length.toDouble();
    return intersection / union;
  }

  void _showWinnerPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Color(0xFFFFE8BE),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Color(0xFFFFE8BE), width: 3),
          ),
          content: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events, color: Colors.green[700], size: 48),
                SizedBox(height: 12),
                Text('WINNER', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[700])),
                if (_winAmount != null) ...[
                  SizedBox(height: 8),
                  Text('Amount: $_winAmount', style: TextStyle(fontSize: 16, color: Colors.black87)),
                ],
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                  child: Text('OK'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Let content go under AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Transparent AppBar
        elevation: 0, // No shadow
        title: Text('Scan Results'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: VietnameseTiledBackground(
        child: SafeArea(
          child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Processed image with beige border
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFFFE8BE), width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_savedImagePath ?? widget.imagePath),
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Results card (same look as working screen)
              _buildResultCard(),

              SizedBox(height: 20),

              // Winner checking results (replicated)
              if (_isCheckingWinner) ...[
                Card(
                  color: Color(0xFFFFE8BE),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA5362D)),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Checking if ticket is a winner...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ] else if (_isWinner != null && _isWinner == false) ...[
                Card(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFE8BE),
                      border: Border.all(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.red, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Not a Winner',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'This ticket did not match any winning numbers.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ] else if (_winnerCheckError != null) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.pending, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Pending Results',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        _winnerCheckError!,
                        style: TextStyle(fontSize: 14, color: Colors.orange[700]),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ] else if ((widget.city ?? 'Not found') != 'Not found' && (widget.date ?? 'Not found') != 'Not found' && (widget.ticketNumber ?? 'Not found') != 'Not found' && !_shouldCheckWinner()) ...[
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
                          'This drawing has not occurred yet. You will receive a notification after the drawing has occurred.',
                          style: TextStyle(fontSize: 14, color: Colors.orange[700]),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],

              // Bottom padding
              SizedBox(height: 50),

              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFFE8BE),
                    foregroundColor: Colors.black87,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text('Back to Home'),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      color: Color(0xFFFFE8BE),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResultRow('City', widget.city ?? 'Not found', Icons.location_city),
            const SizedBox(height: 12),
            _buildResultRow('Date', widget.date ?? 'Not found', Icons.calendar_today),
            const SizedBox(height: 12),
            _buildResultRow('Ticket Number', widget.ticketNumber ?? 'Not found', Icons.confirmation_number),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String actual, IconData icon) {
    final isFound = actual != 'Not found';
    Color statusColor;
    Color borderColor;
    if (!isFound) {
      statusColor = Colors.red;
      borderColor = Colors.red;
    } else {
      statusColor = Colors.green;
      borderColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFFA5362D), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  actual,
                  style: TextStyle(
                    fontSize: 16,
                    color: isFound ? Colors.black87 : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isFound ? 'Found' : 'Missing',
              style: TextStyle(
                color: statusColor == Colors.red ? Colors.red[700]! : Colors.green[700]!,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
