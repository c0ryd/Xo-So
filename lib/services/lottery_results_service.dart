import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';
import '../config/app_config.dart';
import '../utils/debug_logger.dart';

class LotteryResultsService {
  // Configuration now comes from AppConfig
  static String get _apiGatewayBaseUrl => AppConfig.apiGatewayBaseUrl;
  static String get _identityPoolId => AppConfig.cognitoIdentityPoolId;
  static String get _awsRegion => AppConfig.awsRegion;

  /// Get lottery results from DynamoDB for a specific province and date
  static Future<Map<String, List<String>>?> getResults({
    required String province,
    required DateTime date,
  }) async {
    try {
      DebugLogger.logUserAction('Fetch lottery results', data: {
        'province': province,
        'date': _formatDateForApi(date),
        'isProduction': AppConfig.isProduction
      });

      // Prepare the payload
      final payload = {
        'province': province,
        'date': _formatDateForApi(date),
      };
      
      // Make direct API call without authentication (API Gateway allows it)
      final apiPath = AppConfig.isProduction ? '/prod/fetchResults' : '/dev/fetchResults';
      final apiUrl = '$_apiGatewayBaseUrl$apiPath';
      
      DebugLogger.logConfig('API Gateway Base URL', _apiGatewayBaseUrl);
      DebugLogger.logConfig('API Path', apiPath);
      DebugLogger.logConfig('Full API URL', apiUrl);
      
      DebugLogger.logAPI(apiUrl, payload, category: 'LOTTERY_RESULTS');
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      DebugLogger.logAPIResponse(apiUrl, response.statusCode, response.body, category: 'LOTTERY_RESULTS');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        DebugLogger.logDatabaseOperation('Parse lottery results response', responseData);
        
        if (responseData['success'] == true && responseData['results'] != null) {
          // Convert the results to the expected format
          final resultsData = responseData['results'] as Map<String, dynamic>;
          final Map<String, List<String>> results = {};
          
          DebugLogger.log('Raw results data structure: ${resultsData.keys.toList()}', category: 'LOTTERY_RESULTS');
          
          resultsData.forEach((key, value) {
            DebugLogger.log('Processing key: $key, value type: ${value.runtimeType}', category: 'LOTTERY_RESULTS');
            if (value is List) {
              results[key] = value.cast<String>();
            } else if (value is String) {
              results[key] = [value];
            } else if (value is Map) {
              // Handle nested structure like {"prizes": {"G1": [...], "G2": [...]}}
              final nestedMap = value as Map<String, dynamic>;
              nestedMap.forEach((nestedKey, nestedValue) {
                if (nestedValue is List) {
                  results[nestedKey] = nestedValue.cast<String>();
                }
              });
            }
          });

          // Map raw keys (DB/G1..G8) to display keys expected by UI
          String mapToDisplayKey(String key) {
            final upper = key.toUpperCase();
            switch (upper) {
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
              default:
                return key; // Already in display form or unknown
            }
          }

          final Map<String, List<String>> displayResults = {};
          results.forEach((key, value) {
            displayResults[mapToDisplayKey(key)] = value;
          });

          DebugLogger.logSuccess('Results mapped: ${displayResults.keys.toList()}', category: 'LOTTERY_RESULTS');
          DebugLogger.log('Sample data - First: ${displayResults['First Prize']}, Special: ${displayResults['Special Prize']}', category: 'LOTTERY_RESULTS');
          return displayResults;
        } else if (responseData['success'] == false) {
          DebugLogger.logWarning('No results found for $province on ${_formatDateForApi(date)}: ${responseData['message']}', category: 'LOTTERY_RESULTS');
          return null;
        }
      } else {
        DebugLogger.logError('API request failed: Status=${response.statusCode}', category: 'LOTTERY_RESULTS');
        return null;
      }

      return null;

    } catch (e, stackTrace) {
      DebugLogger.logError('Error fetching results: $e', category: 'LOTTERY_RESULTS', stackTrace: stackTrace);
      return null;
    }
  }

  /// Check if results are available for a specific province and date
  static Future<bool> hasResults({
    required String province,
    required DateTime date,
  }) async {
    try {
      final results = await getResults(province: province, date: date);
      return results != null && results.isNotEmpty;
    } catch (e) {
      print('Error checking for results: $e');
      return false;
    }
  }

  /// Format date for API (YYYY-MM-DD)
  static String _formatDateForApi(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get AWS credentials using Cognito Identity Pool
  static Future<CognitoCredentials> _getAwsCredentials() async {
    try {
      // Create a dummy user pool for unauthenticated access
      final userPool = CognitoUserPool(
        'ap-southeast-1_dummy12345', // Dummy user pool ID
        'dummy1234567890abcdef1234567890' // Dummy client ID
      );
      
      // Create Cognito credentials for unauthenticated access
      final credentials = CognitoCredentials(_identityPoolId, userPool);
      
      // Get AWS credentials for unauthenticated access (pass null for unauthenticated)
      await credentials.getAwsCredentials(null);
      
      print('✅ AWS credentials obtained successfully for results service');
      return credentials;
    } catch (e) {
      print('❌ AWS authentication failed: $e');
      throw Exception('AWS authentication failed: $e');
    }
  }
}
