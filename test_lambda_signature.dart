#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

// Standalone test script for AWS Lambda URL signature
void main() async {
  print('=== AWS Lambda URL Signature Test ===');
  
  // Test with hardcoded credentials for debugging
  // You'll need to replace these with actual credentials
  await testLambdaSignature();
}

Future<void> testLambdaSignature() async {
  // Configuration
  const lambdaUrl = 'https://h2ahnzvnapxrgchykoybejs7ie0eiekx.lambda-url.ap-southeast-1.on.aws/';
  const region = 'ap-southeast-1';
  const service = 'lambda';
  
  // Test payload
  final payload = {
    'ticket': '276226',
    'province': 'Tiền Giang',
    'date': '2025-08-03',
    'region': 'south',
  };
  
  print('Testing Lambda URL: $lambdaUrl');
  print('Payload: ${json.encode(payload)}');
  
  // You'll need to get real credentials - this is just a placeholder
  print('\n❌ ERROR: This script needs real AWS credentials to work.');
  print('Please get temporary credentials from the Cognito Identity Pool and update this script.');
  print('\nTo get credentials, you can:');
  print('1. Use the Flutter app to trigger the _getAwsCredentials() method');
  print('2. Add debug prints to see the actual access key, secret key, and session token');
  print('3. Update this script with those real values');
  
  // Demonstrate the signature process with placeholder values
  await demonstrateSignatureProcess(lambdaUrl, payload, region, service);
}

Future<void> demonstrateSignatureProcess(
  String lambdaUrl, 
  Map<String, dynamic> payload, 
  String region, 
  String service
) async {
  print('\n=== SIGNATURE PROCESS DEMONSTRATION ===');
  
  // Placeholder credentials - replace with real ones
  const accessKey = 'PLACEHOLDER_ACCESS_KEY';
  const secretKey = 'PLACEHOLDER_SECRET_KEY';
  const sessionToken = 'PLACEHOLDER_SESSION_TOKEN';
  
  final body = json.encode(payload);
  final uri = Uri.parse(lambdaUrl);
  
  // Create timestamp
  final now = DateTime.now().toUtc();
  final dateTime = now.toIso8601String().replaceAll(RegExp(r'[:\-]'), '').split('.')[0] + 'Z';
  final date = dateTime.substring(0, 8);
  
  print('DateTime: $dateTime');
  print('Date: $date');
  
  // Create headers
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Host': uri.host,
    'X-Amz-Date': dateTime,
    'X-Amz-Security-Token': sessionToken,
  };
  
  print('\nHeaders:');
  headers.forEach((key, value) {
    print('  $key: $value');
  });
  
  // Step 1: Create canonical request
  final canonicalRequest = createCanonicalRequest('POST', headers, body);
  print('\nCanonical Request:');
  print(canonicalRequest);
  
  // Step 2: Create string to sign
  final credentialScope = '$date/$region/$service/aws4_request';
  final stringToSign = createStringToSign(dateTime, credentialScope, canonicalRequest);
  print('\nString to Sign:');
  print(stringToSign);
  
  // Step 3: Calculate signature
  final signature = calculateSignature(secretKey, date, region, service, stringToSign);
  print('\nSignature: $signature');
  
  // Step 4: Create authorization header
  final signedHeaders = 'content-type;host;x-amz-date;x-amz-security-token';
  final authorization = 'AWS4-HMAC-SHA256 '
      'Credential=$accessKey/$credentialScope, '
      'SignedHeaders=$signedHeaders, '
      'Signature=$signature';
  
  print('\nAuthorization Header:');
  print(authorization);
  
  print('\n=== WHAT YOU NEED TO DO ===');
  print('1. Run the Flutter app and trigger a lottery scan');
  print('2. Look at the debug output in the terminal');
  print('3. Copy the real AWS credentials (access key, secret, session token)');
  print('4. Update this script with those real values');
  print('5. Run this script again to test the signature');
}

String createCanonicalRequest(String method, Map<String, String> headers, String body) {
  // Sort headers by key (case-insensitive)
  final sortedHeaders = Map.fromEntries(
    headers.entries.map((e) => MapEntry(e.key.toLowerCase(), e.value.trim()))
  )..removeWhere((key, value) => key == 'authorization');
  
  final canonicalHeaders = sortedHeaders.entries
      .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  
  final signedHeaders = canonicalHeaders.map((e) => e.key).join(';');
  final canonicalHeadersStr = canonicalHeaders
      .map((e) => '${e.key}:${e.value}')
      .join('\n') + '\n';
  
  final payloadHash = sha256.convert(utf8.encode(body)).toString();
  
  // For Lambda URLs: method, path (/), empty query, headers, signed headers, payload hash
  return [
    method,
    '/', // Always root path for Lambda URLs
    '', // Always empty query string for Lambda URLs
    canonicalHeadersStr,
    signedHeaders,
    payloadHash,
  ].join('\n');
}

String createStringToSign(String dateTime, String credentialScope, String canonicalRequest) {
  final canonicalRequestHash = sha256.convert(utf8.encode(canonicalRequest)).toString();
  
  return [
    'AWS4-HMAC-SHA256',
    dateTime,
    credentialScope,
    canonicalRequestHash,
  ].join('\n');
}

String calculateSignature(String secretKey, String date, String region, String service, String stringToSign) {
  final kDate = _hmacSha256(utf8.encode('AWS4$secretKey'), utf8.encode(date));
  final kRegion = _hmacSha256(kDate, utf8.encode(region));
  final kService = _hmacSha256(kRegion, utf8.encode(service));
  final kSigning = _hmacSha256(kService, utf8.encode('aws4_request'));
  final signature = _hmacSha256(kSigning, utf8.encode(stringToSign));
  
  return signature.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

List<int> _hmacSha256(List<int> key, List<int> data) {
  final hmac = Hmac(sha256, key);
  return hmac.convert(data).bytes;
}

// Helper function to actually test the API call when you have real credentials
Future<void> testWithRealCredentials({
  required String accessKey,
  required String secretKey,
  required String sessionToken,
}) async {
  const lambdaUrl = 'https://h2ahnzvnapxrgchykoybejs7ie0eiekx.lambda-url.ap-southeast-1.on.aws/';
  const region = 'ap-southeast-1';
  const service = 'lambda';
  
  final payload = {
    'ticket': '276226',
    'province': 'Tiền Giang',
    'date': '2025-08-03',
    'region': 'south',
  };
  
  final body = json.encode(payload);
  final uri = Uri.parse(lambdaUrl);
  
  final now = DateTime.now().toUtc();
  final dateTime = now.toIso8601String().replaceAll(RegExp(r'[:\-]'), '').split('.')[0] + 'Z';
  final date = dateTime.substring(0, 8);
  
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Host': uri.host,
    'X-Amz-Date': dateTime,
    'X-Amz-Security-Token': sessionToken,
  };
  
  final canonicalRequest = createCanonicalRequest('POST', headers, body);
  final credentialScope = '$date/$region/$service/aws4_request';
  final stringToSign = createStringToSign(dateTime, credentialScope, canonicalRequest);
  final signature = calculateSignature(secretKey, date, region, service, stringToSign);
  
  final signedHeaders = 'content-type;host;x-amz-date;x-amz-security-token';
  final authorization = 'AWS4-HMAC-SHA256 '
      'Credential=$accessKey/$credentialScope, '
      'SignedHeaders=$signedHeaders, '
      'Signature=$signature';
  
  final requestHeaders = {
    ...headers,
    'Authorization': authorization,
  };
  
  print('\n=== MAKING ACTUAL REQUEST ===');
  print('URL: $lambdaUrl');
  print('Headers:');
  requestHeaders.forEach((key, value) {
    print('  $key: ${value.length > 50 ? value.substring(0, 50) + "..." : value}');
  });
  
  try {
    final response = await http.post(
      uri,
      headers: requestHeaders,
      body: body,
    );
    
    print('\n=== RESPONSE ===');
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
    
    if (response.statusCode == 200) {
      print('\n✅ SUCCESS! API call worked!');
    } else {
      print('\n❌ FAILED with status ${response.statusCode}');
    }
  } catch (e) {
    print('\n❌ ERROR making request: $e');
  }
}