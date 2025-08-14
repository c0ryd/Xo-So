import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';

class LotteryResultsService {
  static const String _apiGatewayBaseUrl = 'https://u9maewv4ch.execute-api.ap-southeast-1.amazonaws.com';
  static const String _identityPoolId = 'ap-southeast-1:9728af83-62a8-410f-a585-53de188a5079';
  static const String _awsRegion = 'ap-southeast-1';

  /// Get lottery results from DynamoDB for a specific province and date
  static Future<Map<String, List<String>>?> getResults({
    required String province,
    required DateTime date,
  }) async {
    try {
      print('Fetching results for $province on ${_formatDateForApi(date)}');

      // Get AWS credentials for authenticated API call
      final credentials = await _getAwsCredentials();
      
      // Create signed request for API Gateway
      final awsSigV4Client = AwsSigV4Client(
        credentials.accessKeyId!,
        credentials.secretAccessKey!,
        _apiGatewayBaseUrl,
        sessionToken: credentials.sessionToken,
        region: _awsRegion,
      );

      // Prepare the payload
      final payload = {
        'province': province,
        'date': _formatDateForApi(date),
      };
      
      final signedRequest = SigV4Request(
        awsSigV4Client,
        method: 'POST',
        path: '/dev/fetchResults',
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );
      
      print('🔍 Making authenticated request to: ${signedRequest.url}');
      print('🔍 Payload: ${json.encode(payload)}');
      print('🔍 Headers: ${signedRequest.headers}');
      
      final response = await http.post(
        Uri.parse(signedRequest.url!),
        headers: signedRequest.headers?.cast<String, String>(),
        body: signedRequest.body,
      );

      print('📡 Get results response: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['success'] == true && responseData['results'] != null) {
          // Convert the results to the expected format
          final resultsData = responseData['results'] as Map<String, dynamic>;
          final Map<String, List<String>> results = {};
          
          resultsData.forEach((key, value) {
            if (value is List) {
              results[key] = value.cast<String>();
            } else if (value is String) {
              results[key] = [value];
            }
          });
          
          print('✅ Results fetched successfully: ${results.keys}');
          return results;
        } else if (responseData['success'] == false) {
          print('ℹ️ No results found for $province on ${_formatDateForApi(date)}');
          return null;
        }
      } else {
        print('❌ API request failed: Status=${response.statusCode}, Response=${response.body}');
      }

      return null;

    } catch (e) {
      print('❌ Error fetching results: $e');
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
