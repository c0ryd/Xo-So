import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../widgets/vietnamese_tiled_background.dart';
import '../services/lottery_results_service.dart';

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
    
    setState(() {
      if (isFuture || (isToday && !_hasResultsForToday())) {
        // Future dates or today before results are available
        _status = ResultStatus.pending;
      } else {
        _status = ResultStatus.loading;
      }
    });

    if (!isFuture && (isPast || (isToday && _hasResultsForToday()))) {
      // Try to fetch real results from the database
      try {
        final results = await LotteryResultsService.getResults(
          province: widget.province,
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
      } catch (e) {
        print('❌ Error loading results from database: $e');
        setState(() {
          _status = isPast ? ResultStatus.notAvailable : ResultStatus.pending;
          _errorMessage = 'Failed to load results. Please try again.';
        });
      }
    }
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
        title: Text('${widget.province} Results', style: TextStyle(color: Color(0xFFFFD966))),
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
                'Loading results...',
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
                    ? 'Results Pending'
                    : 'Drawing Scheduled',
                  style: TextStyle(
                    color: Color(0xFFFFD966),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  isToday
                    ? 'Drawing not yet complete'
                    : 'Drawing results will be available on this date',
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
                  'Results Not Available',
                  style: TextStyle(
                    color: Color(0xFFFFD966),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'No drawing results found for this date and province',
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
        children: [
          Icon(
            Icons.calendar_today,
            color: Color(0xFFFFD966),
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.province,
                  style: TextStyle(
                    color: Color(0xFFFFD966),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatDate(widget.date),
                  style: TextStyle(
                    color: Color(0xFFFFD966),
                    fontSize: 14,
                  ),
                ),
              ],
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
                        'No results available for this date',
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
          'No results available',
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
              child: Text(
                'Lottery Results',
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
              prizeName,
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
              prizeName,
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
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
