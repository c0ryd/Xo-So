import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../widgets/vietnamese_tiled_background.dart';
import '../services/lottery_results_service.dart';
import '../services/language_service.dart';
import '../utils/debug_logger.dart';

class ProvinceResultsScreen extends StatefulWidget {
  final String province;
  final DateTime date;

  const ProvinceResultsScreen({
    Key? key,
    required this.province,
    required this.date,
  }) : super(key: key);

  @override
  State<ProvinceResultsScreen> createState() => _ProvinceResultsScreenState();
}

enum ResultStatus { loading, pending, available, notAvailable }

class _ProvinceResultsScreenState extends State<ProvinceResultsScreen> {
  ResultStatus _status = ResultStatus.loading;
  Map<String, List<String>>? _results;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final now = DateTime.now();
    final selectedDate = widget.date;
    final isToday = _isSameDay(selectedDate, now);
    final isFuture = selectedDate.isAfter(now);
    final isPast = selectedDate.isBefore(DateTime(now.year, now.month, now.day));
    
    DebugLogger.logUserAction('Loading province results', data: {
      'province': widget.province,
      'date': selectedDate.toIso8601String().substring(0, 10),
      'isToday': isToday,
      'isFuture': isFuture,
      'isPast': isPast,
      'hasResultsForToday': _hasResultsForToday(),
    });
    
    setState(() {
      if (isFuture) {
        _status = ResultStatus.pending;
        DebugLogger.log('Status set to PENDING (future date)', category: 'PROVINCE_RESULTS');
      } else {
        _status = ResultStatus.loading;
        DebugLogger.log('Status set to LOADING (will fetch from API regardless of time)', category: 'PROVINCE_RESULTS');
      }
    });

    if (!isFuture) {
      // Always attempt fetch for today/past; UI will decide pending vs notAvailable
      DebugLogger.log('Attempting to fetch results from API...', category: 'PROVINCE_RESULTS');
      try {
        final provinceForApi = _toVietnameseProvince(widget.province);
        DebugLogger.log('Province normalized for API: $provinceForApi', category: 'PROVINCE_RESULTS');
        final results = await LotteryResultsService.getResults(
          province: provinceForApi,
          date: selectedDate,
        );
        
        setState(() {
          if (results != null && results.isNotEmpty) {
            _status = ResultStatus.available;
            _results = results;
            print('✅ Loaded ${results.length} prize categories from database');
          } else if (isPast) {
            _status = ResultStatus.notAvailable;
            print('ℹ️ No results found in database for past date');
          } else {
            _status = ResultStatus.pending;
            print('ℹ️ Results not yet available for today');
          }
        });

        // 🚀 NEW FEATURE: Auto-trigger data fetching and ticket processing
        await _checkAndTriggerDataFetch(selectedDate, results == null || results.isEmpty);
        
      } catch (e) {
        print('❌ Error loading results from database: $e');
        setState(() {
          _status = isPast ? ResultStatus.notAvailable : ResultStatus.pending;
          _errorMessage = 'Failed to load results. Please try again.';
        });
      }
    }
  }

  /// Check if we should trigger data fetching and ticket processing
  Future<void> _checkAndTriggerDataFetch(DateTime selectedDate, bool noResultsFound) async {
    final now = DateTime.now();
    final vietnamNow = now.add(Duration(hours: 7)); // Vietnam is UTC+7
    final daysDifference = now.difference(selectedDate).inDays;
    
    // Trigger conditions:
    // 1. After 4pm VN time on current day
    // 2. Within 30 days in the past
    // 3. No results found in database
    
    final isAfter4PMToday = _isSameDay(selectedDate, now) && vietnamNow.hour >= 16;
    final isWithin30Days = daysDifference >= 0 && daysDifference <= 30;
    
    if ((isAfter4PMToday || isWithin30Days) && noResultsFound) {
      print('🚀 TRIGGER CONDITIONS MET: Initiating background data fetch and ticket processing');
      print('   → Selected date: ${selectedDate.toIso8601String().substring(0, 10)}');
      print('   → Days ago: $daysDifference');
      print('   → Vietnam time: ${vietnamNow.hour}:${vietnamNow.minute}');
      print('   → After 4PM today: $isAfter4PMToday');
      print('   → Within 30 days: $isWithin30Days');
      
      try {
        // Trigger data fetching for all provinces on selected date
        await _triggerDataFetchAndProcessing(selectedDate);
        
        // After background processing, try to reload results for this province
        await Future.delayed(Duration(seconds: 3)); // Give backend time to process
        await _reloadResultsAfterFetch();
        
      } catch (e) {
        print('⚠️ Background data fetch failed: $e');
        // Don't show error to user - this is background processing
      }
    } else {
      print('ℹ️ No background fetch needed:');
      print('   → After 4PM today: $isAfter4PMToday, Within 30 days: $isWithin30Days, No results: $noResultsFound');
    }
  }

  /// Trigger AWS Lambda to fetch data for all provinces on selected date and process tickets
  Future<void> _triggerDataFetchAndProcessing(DateTime selectedDate) async {
    final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
    
    print('🔄 Triggering fetchDailyResults Lambda for date: $dateStr');
    
    // Call the fetchDailyResults endpoint which will:
    // 1. Fetch results for ALL provinces that had drawings on this date
    // 2. Populate the database
    // 3. Process any unprocessed tickets
    
    final apiPath = AppConfig.isProduction ? '/prod/fetchDailyResults' : '/dev/fetchDailyResults';
    final apiUrl = '${AppConfig.apiGatewayBaseUrl}$apiPath';
    
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'date': dateStr,
        'triggerSource': 'province_results_screen',
        'requestedProvince': widget.province,
      }),
    );
    
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      print('✅ Background data fetch initiated successfully');
      print('   → Response: ${responseData['message'] ?? 'Processing started'}');
    } else {
      print('❌ Background data fetch failed: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to trigger background data fetch');
    }
  }

  /// Reload results after background fetch completes
  Future<void> _reloadResultsAfterFetch() async {
    print('🔄 Reloading results after background fetch...');
    
    try {
      final provinceForApi = _toVietnameseProvince(widget.province);
      final results = await LotteryResultsService.getResults(
        province: provinceForApi,
        date: widget.date,
      );
      
      if (results != null && results.isNotEmpty) {
        setState(() {
          _status = ResultStatus.available;
          _results = results;
        });
        print('🎉 Results now available after background fetch: ${results.length} prize categories');
      } else {
        print('ℹ️ Results still not available after background fetch - may need more time');
      }
    } catch (e) {
      print('⚠️ Error reloading results after fetch: $e');
    }
  }

  String _toVietnameseProvince(String name) {
    // Complete mapping for DB lookup - MUST match database spelling exactly
    const mapping = {
      // Northern provinces
      'Hanoi': 'Hà Nội',
      'Ha Noi': 'Hà Nội',
      'Hai Phong': 'Hải Phòng',
      'Quang Ninh': 'Quảng Ninh',
      'Bac Ninh': 'Bắc Ninh',
      'Thai Binh': 'Thái Bình',
      'Nam Dinh': 'Nam Định',
      'Hai Duong': 'Hải Dương',
      'Hung Yen': 'Hưng Yên',
      'Vinh Phuc': 'Vĩnh Phúc',
      
      // Central provinces  
      'Da Nang': 'Đà Nẵng',
      'Quang Nam': 'Quảng Nam',
      'Quang Tri': 'Quảng Trị',
      'Thua Thien Hue': 'Thừa Thiên Huế',
      'Quang Binh': 'Quảng Bình',
      'Quang Ngai': 'Quảng Ngãi',
      'Binh Dinh': 'Bình Định',
      'Phu Yen': 'Phú Yên',
      'Khanh Hoa': 'Khánh Hòa',
      'Ninh Thuan': 'Ninh Thuận',
      'Binh Thuan': 'Bình Thuận',
      'Dak Lak': 'Đắk Lắk',
      'Dak Nong': 'Đắk Nông',
      'Lam Dong': 'Lâm Đồng',
      'Gia Lai': 'Gia Lai',
      'Kon Tum': 'Kon Tum',
      
      // Southern provinces
      'Ho Chi Minh': 'Hồ Chí Minh',
      'Binh Duong': 'Bình Dương',  // 🔧 THE MISSING MAPPING!
      'Dong Nai': 'Đồng Nai',
      'Ba Ria Vung Tau': 'Bà Rịa - Vũng Tàu',
      'Tay Ninh': 'Tây Ninh',
      'Binh Phuoc': 'Bình Phước',
      'Long An': 'Long An',
      'Tien Giang': 'Tiền Giang',
      'Ben Tre': 'Bến Tre',
      'Tra Vinh': 'Trà Vinh',
      'Vinh Long': 'Vĩnh Long',
      'Dong Thap': 'Đồng Tháp',
      'An Giang': 'An Giang',
      'Kien Giang': 'Kiên Giang',
      'Can Tho': 'Cần Thơ',
      'Hau Giang': 'Hậu Giang',
      'Soc Trang': 'Sóc Trăng',
      'Bac Lieu': 'Bạc Liêu',
      'Ca Mau': 'Cà Mau',
    };
    
    final mapped = mapping[name] ?? name;
    print('🔄 Province mapping: "$name" -> "$mapped"');
    return mapped;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  bool _hasResultsForToday() {
    // In a real app, this would check if results are available for today
    // For demo purposes, let's say results are available after 8 PM
    final now = DateTime.now();
    return now.hour >= 20; // 8 PM
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Let content go under AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Transparent AppBar
        elevation: 0, // No shadow
        title: Text('${_getDisplayProvinceName(widget.province)} ${AppLocalizations.of(context)!.todaysDrawings}', style: TextStyle(color: Color(0xFFFFD966))),
        iconTheme: IconThemeData(color: Color(0xFFFFD966)), // Gold back button
      ),
      body: VietnameseTiledBackground(
        child: SafeArea(
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_status) {
      case ResultStatus.loading:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA5362D)),
              ),
              SizedBox(height: 16),
                              Text(
                  AppLocalizations.of(context)!.loading,
                  style: TextStyle(
                  color: Color(0xFFFFD966),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      
      case ResultStatus.pending:
        return _buildPendingState();
      
      case ResultStatus.available:
        return _buildResultsList();
      
      case ResultStatus.notAvailable:
        return _buildNotAvailableState();
    }
  }

  Widget _buildPendingState() {
    final now = DateTime.now();
    final isToday = _isSameDay(widget.date, now);
    
    return Column(
      children: [
        // Date and Province Header
        _buildHeader(),
        // Pending message
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.schedule,
                    color: Colors.orange[700],
                    size: 64,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  isToday 
                    ? AppLocalizations.of(context)!.pending
                    : AppLocalizations.of(context)!.drawingScheduled,
                  style: TextStyle(
                    color: Color(0xFFFFD966),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  isToday
                    ? AppLocalizations.of(context)!.drawingNotComplete
                    : AppLocalizations.of(context)!.drawingResultsAvailable,
                  style: TextStyle(
                    color: Color(0xFFFFD966),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotAvailableState() {
    return Column(
      children: [
        // Date and Province Header
        _buildHeader(),
        // Not available message
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.grey[600],
                    size: 64,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context)!.resultsNotAvailableYet,
                  style: TextStyle(
                    color: Color(0xFFFFD966),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.noDrawingResults,
                  style: TextStyle(
                    color: Color(0xFFFFD966),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: EdgeInsets.all(16),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            color: Color(0xFFFFD966),
            size: 28,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              _formatDate(widget.date),
              style: TextStyle(
                color: Color(0xFFFFD966),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return Column(
      children: [
        // Date and Province Header
        _buildHeader(),
        // Results List
        Expanded(
          child: _results == null || _results!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey,
                        size: 64,
                      ),
                      SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.noResultsForDate,
                        style: TextStyle(
                          color: Color(0xFFFFD966),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildAllPrizesCard(),
                      SizedBox(height: 16), // Bottom padding
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAllPrizesCard() {
    if (_results == null || _results!.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noResultsAvailable,
          style: TextStyle(
            color: Color(0xFFFFD966),
            fontSize: 16,
          ),
        ),
      );
    }

    // Define the correct order from top to bottom
    final prizeOrder = [
      'Eighth Prize',
      'Seventh Prize', 
      'Sixth Prize',
      'Fifth Prize',
      'Fourth Prize',
      'Third Prize',
      'Second Prize',
      'First Prize',
      'Special Prize'
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFFFD966).withOpacity(0.3)),
                ),
              ),
              child:                 Text(
                  AppLocalizations.of(context)!.lotteryResults,
                style: TextStyle(
                  color: Color(0xFFFFD966),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // All prizes in order
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: prizeOrder.where((prizeName) => _results!.containsKey(prizeName)).map((prizeName) {
                  final numbers = _results![prizeName]!;
                  return _buildPrizeRow(prizeName, numbers);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrizeRow(String prizeName, List<String> numbers) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFFFD966).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prize name
          Container(
            width: double.infinity,
            child: Text(
              _translatePrizeName(prizeName),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFD966),
              ),
            ),
          ),
          SizedBox(height: 12),
          // Numbers
          Container(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: numbers.map((number) => Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(0xFFFFD966),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  number,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeCard(String prizeName, List<String> numbers) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Color(0xFFFFE8BE),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prize header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFA5362D),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              _translatePrizeName(prizeName),
              style: TextStyle(
                color: Color(0xFFFFD966),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Numbers
          Padding(
            padding: EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: numbers.map((number) => Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  number,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Simple DD-MM-YYYY format, no translation needed
    String day = date.day.toString().padLeft(2, '0');
    String month = date.month.toString().padLeft(2, '0');
    String year = date.year.toString();
    return '$day-$month-$year';
  }

  String _getDisplayProvinceName(String province) {
    // Map province names to proper Vietnamese with accents
    const provinceMap = {
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
    
    return provinceMap[province] ?? province;
  }

  String _translatePrizeName(String prizeName) {
    switch (prizeName) {
      case 'Special Prize':
        return AppLocalizations.of(context)!.specialPrize;
      case 'First Prize':
        return AppLocalizations.of(context)!.firstPrize;
      case 'Second Prize':
        return AppLocalizations.of(context)!.secondPrize;
      case 'Third Prize':
        return AppLocalizations.of(context)!.thirdPrize;
      case 'Fourth Prize':
        return AppLocalizations.of(context)!.fourthPrize;
      case 'Fifth Prize':
        return AppLocalizations.of(context)!.fifthPrize;
      case 'Sixth Prize':
        return AppLocalizations.of(context)!.sixthPrize;
      case 'Seventh Prize':
        return AppLocalizations.of(context)!.seventhPrize;
      case 'Eighth Prize':
        return AppLocalizations.of(context)!.eighthPrize;
      default:
        return prizeName;
    }
  }
}
