import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';
import '../config/app_config.dart';
import 'notification_service.dart';

class TicketStorageService {
  // Configuration now comes from AppConfig
  static String get _apiGatewayBaseUrl => AppConfig.apiGatewayBaseUrl;
  static String get _identityPoolId => AppConfig.cognitoIdentityPoolId;
  static String get _awsRegion => AppConfig.awsRegion;


  /// Store a scanned ticket in AWS DynamoDB for processing after the drawing
  /// Returns the ticket ID if successful, null if failed
  static Future<String?> storeTicket({
    required String ticketNumber,
    required String province,
    required String drawDate,
    required String region,
    required String ocrRawText,
    String? imagePath,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('Error: User not authenticated');
        return null;
      }

      // Get device token for notifications
      final deviceToken = NotificationService.currentToken;
      if (deviceToken == null) {
        print('Warning: Device token not available, notifications may not work');
      }

      // Prepare the payload
      final payload = {
        'userId': user.id,
        'ticketNumber': ticketNumber,
        'province': province,
        'drawDate': drawDate,
        'region': region,
        'deviceToken': deviceToken,
        'userEmail': user.email ?? '',
        'scannedAt': DateTime.now().toUtc().toIso8601String(),
        'ocrRawText': ocrRawText,
        'imagePath': imagePath ?? '', // Include image path
      };

      print('Storing ticket with payload: $payload');

      // Make direct API call (no authentication needed for API Gateway)
      final apiPath = AppConfig.isProduction ? '/prod/storeTicket' : '/dev/storeTicket';
      final apiUrl = '$_apiGatewayBaseUrl$apiPath';
      
      print('Making direct request to: $apiUrl');
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      print('Store ticket response: ${response.statusCode} - ${response.body}');
      print('Request URL: $apiUrl');
      print('Payload sent: ${json.encode(payload)}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final ticketId = responseData['ticketId'];
          if (responseData['isDuplicate'] == true) {
            print('Duplicate ticket detected - existing ID: $ticketId');
            print('Message: ${responseData['message']}');
          } else {
            print('Ticket stored successfully with ID: $ticketId');
          }
          
          // Subscribe user to notifications for this province/region
          await _subscribeToRelevantNotifications(province, region);
          
          return ticketId;
        }
      }

      print('❌ STORAGE FAILED: Status=${response.statusCode}, Response=${response.body}');
      print('URL: $apiUrl');
      return null;

    } catch (e) {
      print('Error storing ticket: $e');
      return null;
    }
  }

  /// Get user's stored tickets from AWS
  static Future<List<Map<String, dynamic>>> getUserTickets({int limit = 50}) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('Error: User not authenticated');
        return [];
      }

      // This would require another Lambda function to get user tickets
      // For now, we'll return an empty list
      // TODO: Implement get_user_tickets Lambda function
      
      return [];
    } catch (e) {
      print('Error getting user tickets: $e');
      return [];
    }
  }

  /// Check if a ticket should be stored (ALL tickets are now stored)
  static bool shouldStoreTicket(String drawDate) {
    try {
      // Parse the ticket date (expected format: DD-MM-YYYY)
      final dateParts = drawDate.split('-');
      if (dateParts.length != 3) return false;
      
      final ticketDate = DateTime(
        int.parse(dateParts[2]), // year
        int.parse(dateParts[1]), // month
        int.parse(dateParts[0])  // day
      );
      
      // Get current Vietnam time (simplified - using local time)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // CHANGED: Always store ALL tickets regardless of time or date
      // This allows tickets to be stored even after drawings have occurred
      print('Ticket date: $ticketDate');
      print('Today: $today');
      print('Current time: $now');
      print('Storing ALL tickets - no time restrictions');
      
      return true;
    } catch (e) {
      print('Error parsing date for storage check: $e');
      return false;
    }
  }



  /// Subscribe user to relevant notifications based on province and region
  static Future<void> _subscribeToRelevantNotifications(String province, String region) async {
    try {
      // Subscribe to regional notifications
      await NotificationService.subscribeToRegion(region);
      
      // Subscribe to province-specific notifications
      await NotificationService.subscribeToProvince(province);
      
      print('Subscribed to notifications for $province ($region)');
    } catch (e) {
      print('Error subscribing to notifications: $e');
    }
  }

  /// Convert date from DD-MM-YYYY to YYYY-MM-DD format for API
  static String convertDateToApiFormat(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return dateStr;
      
      return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  /// Get region for a city (same logic as in main app)
  static String? getRegionForCity(String cityName, Map<String, dynamic> citiesData) {
    if (citiesData.isEmpty) return null;
    
    // Create normalized version for matching
    final normalizedCityName = normalizeVietnameseText(cityName);
    
    for (final region in citiesData['regions']) {
      final cities = region['cities'] as List<dynamic>;
      
      // Check both exact match and normalized match
      for (final city in cities) {
        final cityStr = city.toString();
        if (cityStr == cityName || 
            normalizeVietnameseText(cityStr) == normalizedCityName ||
            cityStr.toLowerCase() == cityName.toLowerCase()) {
          final englishName = region['english_name'] as String;
          print('✅ Found region for "$cityName" -> ${englishName.toLowerCase()}');
          
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
    }
    
    // Fallback for special cases
    if (cityName.contains('Hồ Chí Minh') || cityName.contains('TP.')) {
      return 'south';
    }
    
    print('❌ No region found for city: "$cityName" (normalized: "$normalizedCityName")');
    return null;
  }
  
  /// Normalize Vietnamese text by removing diacritics for matching
  static String normalizeVietnameseText(String text) {
    return text
        .replaceAll('ă', 'a')
        .replaceAll('â', 'a')
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ả', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ạ', 'a')
        .replaceAll('ắ', 'a')
        .replaceAll('ằ', 'a')
        .replaceAll('ẳ', 'a')
        .replaceAll('ẵ', 'a')
        .replaceAll('ặ', 'a')
        .replaceAll('ấ', 'a')
        .replaceAll('ầ', 'a')
        .replaceAll('ẩ', 'a')
        .replaceAll('ẫ', 'a')
        .replaceAll('ậ', 'a')
        .replaceAll('Ă', 'A')
        .replaceAll('Â', 'A')
        .replaceAll('Á', 'A')
        .replaceAll('À', 'A')
        .replaceAll('Ả', 'A')
        .replaceAll('Ã', 'A')
        .replaceAll('Ạ', 'A')
        .replaceAll('Ắ', 'A')
        .replaceAll('Ằ', 'A')
        .replaceAll('Ẳ', 'A')
        .replaceAll('Ẵ', 'A')
        .replaceAll('Ặ', 'A')
        .replaceAll('Ấ', 'A')
        .replaceAll('Ầ', 'A')
        .replaceAll('Ẩ', 'A')
        .replaceAll('Ẫ', 'A')
        .replaceAll('Ậ', 'A')
        .replaceAll('đ', 'd')
        .replaceAll('Đ', 'D')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ẻ', 'e')
        .replaceAll('ẽ', 'e')
        .replaceAll('ẹ', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ế', 'e')
        .replaceAll('ề', 'e')
        .replaceAll('ể', 'e')
        .replaceAll('ễ', 'e')
        .replaceAll('ệ', 'e')
        .replaceAll('É', 'E')
        .replaceAll('È', 'E')
        .replaceAll('Ẻ', 'E')
        .replaceAll('Ẽ', 'E')
        .replaceAll('Ẹ', 'E')
        .replaceAll('Ê', 'E')
        .replaceAll('Ế', 'E')
        .replaceAll('Ề', 'E')
        .replaceAll('Ể', 'E')
        .replaceAll('Ễ', 'E')
        .replaceAll('Ệ', 'E')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('ỉ', 'i')
        .replaceAll('ĩ', 'i')
        .replaceAll('ị', 'i')
        .replaceAll('Í', 'I')
        .replaceAll('Ì', 'I')
        .replaceAll('Ỉ', 'I')
        .replaceAll('Ĩ', 'I')
        .replaceAll('Ị', 'I')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ỏ', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ọ', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ố', 'o')
        .replaceAll('ồ', 'o')
        .replaceAll('ổ', 'o')
        .replaceAll('ỗ', 'o')
        .replaceAll('ộ', 'o')
        .replaceAll('ơ', 'o')
        .replaceAll('ớ', 'o')
        .replaceAll('ờ', 'o')
        .replaceAll('ở', 'o')
        .replaceAll('ỡ', 'o')
        .replaceAll('ợ', 'o')
        .replaceAll('Ó', 'O')
        .replaceAll('Ò', 'O')
        .replaceAll('Ỏ', 'O')
        .replaceAll('Õ', 'O')
        .replaceAll('Ọ', 'O')
        .replaceAll('Ô', 'O')
        .replaceAll('Ố', 'O')
        .replaceAll('Ồ', 'O')
        .replaceAll('Ổ', 'O')
        .replaceAll('Ỗ', 'O')
        .replaceAll('Ộ', 'O')
        .replaceAll('Ơ', 'O')
        .replaceAll('Ớ', 'O')
        .replaceAll('Ờ', 'O')
        .replaceAll('Ở', 'O')
        .replaceAll('Ỡ', 'O')
        .replaceAll('Ợ', 'O')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('ủ', 'u')
        .replaceAll('ũ', 'u')
        .replaceAll('ụ', 'u')
        .replaceAll('ư', 'u')
        .replaceAll('ứ', 'u')
        .replaceAll('ừ', 'u')
        .replaceAll('ử', 'u')
        .replaceAll('ữ', 'u')
        .replaceAll('ự', 'u')
        .replaceAll('Ú', 'U')
        .replaceAll('Ù', 'U')
        .replaceAll('Ủ', 'U')
        .replaceAll('Ũ', 'U')
        .replaceAll('Ụ', 'U')
        .replaceAll('Ư', 'U')
        .replaceAll('Ứ', 'U')
        .replaceAll('Ừ', 'U')
        .replaceAll('Ử', 'U')
        .replaceAll('Ữ', 'U')
        .replaceAll('Ự', 'U')
        .replaceAll('ý', 'y')
        .replaceAll('ỳ', 'y')
        .replaceAll('ỷ', 'y')
        .replaceAll('ỹ', 'y')
        .replaceAll('ỵ', 'y')
        .replaceAll('Ý', 'Y')
        .replaceAll('Ỳ', 'Y')
        .replaceAll('Ỷ', 'Y')
        .replaceAll('Ỹ', 'Y')
        .replaceAll('Ỵ', 'Y')
        .toLowerCase();
  }

  /// Store a ticket with custom payload (for duplicates with copied status)
  static Future<bool> storeTicketWithPayload(Map<String, dynamic> payload) async {
    try {
      // Get AWS credentials
      final credentials = await getAwsCredentials();
      
      // Create SigV4 client
      final awsSigV4Client = AwsSigV4Client(
        credentials.accessKeyId!,
        credentials.secretAccessKey!,
        _apiGatewayBaseUrl,
        serviceName: 'execute-api',
        sessionToken: credentials.sessionToken,
        region: _awsRegion,
      );
      
      final signedRequest = SigV4Request(
        awsSigV4Client,
        method: 'POST',
        path: AppConfig.isProduction ? '/prod/storeTicket' : '/dev/storeTicket',
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );
      
      print('Making authenticated request to: ${signedRequest.url}');
      
      final response = await http.post(
        Uri.parse(signedRequest.url!),
        headers: signedRequest.headers?.cast<String, String>(),
        body: signedRequest.body,
      );
      
      print('Store ticket response: ${response.statusCode} - ${response.body}');
      print('Request URL: ${signedRequest.url}');
      print('Payload sent: ${signedRequest.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final ticketId = responseData['ticketId'];
          final isDuplicate = responseData['isDuplicate'] ?? false;
          
          if (isDuplicate) {
            print('Duplicate ticket detected - existing ID: $ticketId');
            print('Message: ${responseData['message']}');
          } else {
            print('Ticket stored successfully with ID: $ticketId');
          }
          
          // Subscribe to lottery notifications for this province/region
          await NotificationService.subscribeToRegion(payload['region']);
          await NotificationService.subscribeToProvince(payload['province']);
          
          return true;
        }
      }
      
      print('Failed to store ticket: ${response.body}');
      return false;
    } catch (e) {
      print('Error storing ticket with payload: $e');
      return false;
    }
  }

  /// Get current user ID
  static Future<String> getUserId() async {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.id ?? '';
  }

  /// Get current device token
  static Future<String?> getDeviceToken() async {
    return NotificationService.currentToken;
  }

  /// Get current user email
  static Future<String> getUserEmail() async {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.email ?? '';
  }

  /// Duplicate an existing ticket multiple times (preserves all status)
  static Future<bool> duplicateTicket(String ticketId, int quantity) async {
    try {
      final payload = {
        'ticketId': ticketId,
        'quantity': quantity,
      };
      
      // Make direct API call (no authentication needed)
      final apiPath = AppConfig.isProduction ? '/prod/duplicateTicket' : '/dev/duplicateTicket';
      final apiUrl = '$_apiGatewayBaseUrl$apiPath';
      
      print('Making duplicate request to: $apiUrl');
      print('Duplicating ticket $ticketId with quantity $quantity');
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      
      print('Duplicate ticket response: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final duplicatesCreated = responseData['duplicatesCreated'];
          print('Successfully created $duplicatesCreated duplicate tickets');
          return true;
        }
      }
      
      print('Failed to duplicate ticket: ${response.body}');
      return false;
    } catch (e) {
      print('Error duplicating ticket: $e');
      return false;
    }
  }

  /// Get AWS credentials using Cognito Identity Pool
  static Future<CognitoCredentials> getAwsCredentials() async {
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
      
      print('✅ AWS credentials obtained successfully');
      return credentials;
    } catch (e) {
      print('❌ AWS authentication failed: $e');
      throw Exception('AWS authentication failed: $e');
    }
  }
}
