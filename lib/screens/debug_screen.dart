import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../config/app_config.dart';
import '../services/lottery_results_service.dart';
import '../utils/debug_logger.dart';
import '../widgets/vietnamese_tiled_background.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({Key? key}) : super(key: key);

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String _testResults = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _logCurrentConfig();
  }

  void _logCurrentConfig() {
    DebugLogger.logCurrentConfig();
    setState(() {
      _testResults = '🏗️ Configuration logged to console\n\n';
      _testResults += 'Environment: ${AppConfig.isProduction ? "PRODUCTION" : "DEVELOPMENT"}\n';
      _testResults += 'API Gateway: ${AppConfig.apiGatewayBaseUrl}\n';
      _testResults += 'Supabase: ${AppConfig.supabaseUrl}\n';
      _testResults += 'S3 Bucket: ${AppConfig.s3BucketName}\n';
    });
  }

  Future<void> _testRealData() async {
    setState(() {
      _isLoading = true;
      _testResults = '🧪 Testing with real database data...\n\n';
    });

    // Test with data we know exists in the database
    final testCases = [
      ('Hà Nội', DateTime(2025, 7, 24)),
      ('Hà Nội', DateTime(2025, 7, 28)),
      ('Hà Nội', DateTime(2025, 8, 7)),
    ];

    for (final testCase in testCases) {
      final province = testCase.$1;
      final date = testCase.$2;
      
      try {
        DebugLogger.logUserAction('Testing fetchResults', data: {
          'province': province,
          'date': date.toIso8601String()
        });
        
        final results = await LotteryResultsService.getResults(
          province: province,
          date: date,
        );
        
        setState(() {
          _testResults += '📅 $province on ${date.toIso8601String().substring(0, 10)}:\n';
          if (results != null && results.isNotEmpty) {
            _testResults += '  ✅ SUCCESS - Found ${results.keys.length} prize categories\n';
            _testResults += '  🎯 Prizes: ${results.keys.join(', ')}\n';
            if (results['G1'] != null) {
              _testResults += '  🥇 G1 (First): ${results['G1']}\n';
            }
            if (results['DB'] != null) {
              _testResults += '  🏆 DB (Special): ${results['DB']}\n';
            }
          } else {
            _testResults += '  ❌ NO RESULTS FOUND\n';
          }
          _testResults += '\n';
        });
      } catch (e) {
        setState(() {
          _testResults += '📅 $province on ${date.toIso8601String().substring(0, 10)}:\n';
          _testResults += '  💥 ERROR: $e\n\n';
        });
      }
    }

    setState(() {
      _isLoading = false;
      _testResults += '🎯 SUMMARY:\n';
      _testResults += 'Check console for detailed logs!\n';
    });
  }

  Future<void> _testProvinceMapping() async {
    setState(() {
      _isLoading = true;
      _testResults = '🗺️ Testing province name mapping...\n\n';
    });

    // Test common province names used in the app vs database
    final appProvinces = [
      'Hồ Chí Minh', 'Bac Lieu', 'An Giang', 'Ca Mau', 'Can Tho',
      'Dong Thap', 'Hau Giang', 'Kien Giang', 'Long An', 'Soc Trang',
      'Tay Ninh', 'Tien Giang', 'Tra Vinh', 'Vinh Long'
    ];

    final databaseProvinces = ['Hà Nội']; // We know this exists

    setState(() {
      _testResults += 'APP PROVINCES:\n';
      for (final province in appProvinces) {
        _testResults += '  • $province\n';
      }
      _testResults += '\nDATABASE PROVINCES (confirmed):\n';
      for (final province in databaseProvinces) {
        _testResults += '  ✅ $province\n';
      }
      _testResults += '\n⚠️ MISMATCH: App searches for southern provinces,\n';
      _testResults += 'but database has northern data!\n';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('🔍 Debug Panel', style: TextStyle(color: Color(0xFFFFD966))),
        iconTheme: IconThemeData(color: Color(0xFFFFD966)),
      ),
      body: VietnameseTiledBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '🛠️ Debug Tools',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD966),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                
                // Action Buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: _logCurrentConfig,
                      child: Text('📋 Show Config'),
                    ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testRealData,
                      child: Text('🧪 Test Real Data'),
                    ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testProvinceMapping,
                      child: Text('🗺️ Province Mapping'),
                    ),
                  ],
                ),
                
                SizedBox(height: 20),
                
                // Results Display
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isLoading
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: Color(0xFFFFD966)),
                                SizedBox(height: 16),
                                Text(
                                  'Testing APIs...',
                                  style: TextStyle(color: Color(0xFFFFD966)),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: Text(
                              _testResults,
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                Text(
                  '💡 Check console/logs for detailed output',
                  style: TextStyle(
                    color: Color(0xFFFFD966),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
