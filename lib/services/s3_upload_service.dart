import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// S3 Upload Service for ticket images with structured naming
class S3UploadService {
  static const String _identityPoolId = 'ap-southeast-1:9728af83-62a8-410f-a585-53de188a5079';
  static const String _awsRegion = 'ap-southeast-1';
  static const String _s3BucketName = 'xoso-ticket-images';
  
  /// Upload ticket image to S3 with metadata in filename
  /// Returns S3 URL if successful, null if failed
  static Future<String?> uploadTicketImage({
    required Uint8List imageBytes,
    required String ticketNumber,
    required String province,
    required String date,
  }) async {
    try {
      print('🔥 S3: Starting S3 upload for ticket $ticketNumber');
      print('🔥 S3: Image size: ${imageBytes.length} bytes');
      print('🔥 S3: Province: $province, Date: $date');
      
      // Get AWS credentials
      print('🔥 S3: Getting AWS credentials...');
      final credentials = await _getAwsCredentials();
      if (credentials?.accessKeyId == null) {
        print('❌ S3: Failed to get AWS credentials');
        return null;
      }
      
      print('🔥 S3: Got credentials: ${credentials!.accessKeyId}');
      print('🔥 S3: Session token: ${credentials.sessionToken != null ? "Present" : "Missing"}');

      // Generate structured filename
      final fileName = _generateFileName(
        ticketNumber: ticketNumber,
        province: province,
        date: date,
      );

      print('🔥 S3: Generated filename: $fileName');

      // Manual AWS S3 signature generation
      final bodyHash = sha256.convert(imageBytes).toString();
      final s3Url = 'https://$_s3BucketName.s3.$_awsRegion.amazonaws.com/$fileName';
      
      print('🔥 S3: Body SHA256: $bodyHash');
      print('🔥 S3: Target URL: $s3Url');
      
      // Generate manual AWS signature for S3 PUT
      final headers = await _generateAwsSignature(
        method: 'PUT',
        url: s3Url,
        body: imageBytes,
        bodyHash: bodyHash,
        accessKey: credentials.accessKeyId!,
        secretKey: credentials.secretAccessKey!,
        sessionToken: credentials.sessionToken,
      );
      
      print('🔥 S3: Final signed headers: $headers');
      
      final response = await http.put(
        Uri.parse(s3Url),
        headers: headers,
        body: imageBytes,
      );

      print('📤 S3 Response: ${response.statusCode}');
      print('📤 S3 Response Headers: ${response.headers}');
              if (response.statusCode == 200) {
          print('✅ S3 upload successful: $fileName');
          return s3Url;
      } else {
        print('❌ S3 upload failed: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
        print('❌ Response headers: ${response.headers}');
        return null;
      }
    } catch (e) {
      print('❌ S3 upload error: $e');
      return null;
    }
  }

  /// Generate structured filename for S3
  /// Format: tickets/YYYY/MM/DD/province/ticketNumber_userId_timestamp.jpg
  static String _generateFileName({
    required String ticketNumber,
    required String province,
    required String date,
  }) {
    try {
      // Parse date (DD-MM-YYYY format expected)
      DateTime parsedDate;
      if (date.contains('-')) {
        final parts = date.split('-');
        if (parts.length == 3) {
          // Assume DD-MM-YYYY format
          parsedDate = DateTime(
            int.parse(parts[2]), // year
            int.parse(parts[1]), // month
            int.parse(parts[0]), // day
          );
        } else {
          parsedDate = DateTime.now();
        }
      } else {
        parsedDate = DateTime.now();
      }

      final year = parsedDate.year.toString();
      final month = parsedDate.month.toString().padLeft(2, '0');
      final day = parsedDate.day.toString().padLeft(2, '0');
      
      // Clean province name
      final cleanProvince = province
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^\w_]'), '');
      
      // Get user ID
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id?.substring(0, 8) ?? 'unknown';
      
      // Generate timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      return 'tickets/$year/$month/$day/$cleanProvince/${ticketNumber}_${userId}_$timestamp.jpg';
    } catch (e) {
      print('⚠️ Error generating filename: $e');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'tickets/fallback/${ticketNumber}_$timestamp.jpg';
    }
  }

  /// Get AWS credentials using Cognito Identity Pool (unauthenticated access)
  static Future<CognitoCredentials?> _getAwsCredentials() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user for AWS credentials');
        return null;
      }

      print('🔐 Getting AWS credentials for S3 upload');

      // Create a dummy user pool for unauthenticated access (same as ticket storage)
      final userPool = CognitoUserPool(
        'ap-southeast-1_dummy12345', // Dummy user pool ID
        'dummy1234567890abcdef1234567890' // Dummy client ID
      );
      
      // Create Cognito credentials for unauthenticated access
      final credentials = CognitoCredentials(_identityPoolId, userPool);
      
      // Get AWS credentials for unauthenticated access (pass null for unauthenticated)
      await credentials.getAwsCredentials(null);
      
      print('✅ AWS credentials obtained for S3 upload');
      return credentials;
    } catch (e) {
      print('❌ Error getting AWS credentials: $e');
      return null;
    }
  }

  /// Generate AWS Signature Version 4 for S3 requests
  static Future<Map<String, String>> _generateAwsSignature({
    required String method,
    required String url,
    required Uint8List body,
    required String bodyHash,
    required String accessKey,
    required String secretKey,
    String? sessionToken,
  }) async {
    final uri = Uri.parse(url);
    final host = uri.host;
    final path = uri.path;
    
    // Create timestamp
    final now = DateTime.now().toUtc();
    final dateStr = now.toIso8601String().split('T')[0].replaceAll('-', '');
    final timeStr = now.toIso8601String().replaceAll(RegExp(r'[:-]'), '').split('.')[0] + 'Z';
    
    // Create headers
    final headers = <String, String>{
      'host': host,
      'x-amz-date': timeStr,
      'x-amz-content-sha256': bodyHash,
      'content-type': 'image/jpeg',
      'content-length': body.length.toString(),
    };
    
    if (sessionToken != null) {
      headers['x-amz-security-token'] = sessionToken;
    }
    
    // Create canonical headers
    final sortedHeaders = headers.keys.toList()..sort();
    final canonicalHeaders = sortedHeaders.map((key) => '$key:${headers[key]}').join('\n') + '\n';
    final signedHeaders = sortedHeaders.join(';');
    
    // Create canonical request
    final canonicalRequest = [
      method,
      path,
      '', // query string
      canonicalHeaders,
      signedHeaders,
      bodyHash,
    ].join('\n');
    
    // Create string to sign
    final credentialScope = '$dateStr/$_awsRegion/s3/aws4_request';
    final canonicalRequestHash = sha256.convert(utf8.encode(canonicalRequest)).toString();
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      timeStr,
      credentialScope,
      canonicalRequestHash,
    ].join('\n');
    
    // Create signing key
    final kDate = _hmacSha256(utf8.encode('AWS4$secretKey'), utf8.encode(dateStr));
    final kRegion = _hmacSha256(kDate, utf8.encode(_awsRegion));
    final kService = _hmacSha256(kRegion, utf8.encode('s3'));
    final kSigning = _hmacSha256(kService, utf8.encode('aws4_request'));
    
    // Create signature
    final signature = _hmacSha256(kSigning, utf8.encode(stringToSign));
    final signatureHex = signature.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
    
    // Create authorization header
    final authorization = 'AWS4-HMAC-SHA256 Credential=$accessKey/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signatureHex';
    
    return {
      'host': host,
      'x-amz-date': timeStr,
      'x-amz-content-sha256': bodyHash,
      'content-type': 'image/jpeg',
      'content-length': body.length.toString(),
      'authorization': authorization,
      if (sessionToken != null) 'x-amz-security-token': sessionToken,
    };
  }
  
  /// HMAC-SHA256 helper function
  static List<int> _hmacSha256(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(data).bytes;
  }

  /// Test S3 connectivity
  static Future<bool> testS3Connection() async {
    try {
      final credentials = await _getAwsCredentials();
      return credentials?.accessKeyId != null;
    } catch (e) {
      print('❌ S3 connection test failed: $e');
      return false;
    }
  }
}
