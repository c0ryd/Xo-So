import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

// Test script to validate AWS Lambda URL signature
void main() async {
  await testAwsSignature();
}

Future<void> testAwsSignature() async {
  // Test credentials (you'll need to replace these with real ones)
  const accessKey = 'ASIA5IJOW2PDIS5ZD6YI'; // From your debug output
  const secretKey = 'YOUR_SECRET_KEY'; // You'll need to provide this
  const sessionToken = 'YOUR_SESSION_TOKEN'; // You'll need to provide this
  
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
  
  // Create timestamp
  final now = DateTime.now().toUtc();
  final dateTime = now.toIso8601String().replaceAll(RegExp(r'[:\-]'), '').split('.')[0] + 'Z';
  final date = dateTime.substring(0, 8);
  
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Host': uri.host,
    'X-Amz-Date': dateTime,
    'X-Amz-Security-Token': sessionToken,
  };
  
  // Create AWS V4 signature
  final signedHeaders = createAWSSignature(
    method: 'POST',
    uri: uri,
    headers: headers,
    body: body,
    accessKey: accessKey,
    secretKey: secretKey,
    region: region,
    service: service,
    dateTime: dateTime,
  );
  
  print('=== REQUEST INFO ===');
  print('URL: $lambdaUrl');
  print('Body: $body');
  print('Headers:');
  signedHeaders.forEach((key, value) {
    print('  $key: $value');
  });
  
  try {
    final response = await http.post(
      uri,
      headers: signedHeaders,
      body: body,
    );
    
    print('\n=== RESPONSE ===');
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
    
    if (response.statusCode == 200) {
      print('\n✅ SUCCESS! Signature is working correctly.');
    } else {
      print('\n❌ FAILED with status ${response.statusCode}');
    }
  } catch (e) {
    print('\n❌ ERROR: $e');
  }
}

Map<String, String> createAWSSignature({
  required String method,
  required Uri uri,
  required Map<String, String> headers,
  required String body,
  required String accessKey,
  required String secretKey,
  required String region,
  required String service,
  required String dateTime,
}) {
  final date = dateTime.substring(0, 8);
  
  // Step 1: Create canonical request
  final sortedHeaders = Map.fromEntries(
    headers.entries.map((e) => MapEntry(e.key.toLowerCase(), e.value.trim()))
  );
  
  final canonicalHeaders = sortedHeaders.entries
      .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  
  final signedHeaders = canonicalHeaders.map((e) => e.key).join(';');
  final canonicalHeadersStr = canonicalHeaders
      .map((e) => '${e.key}:${e.value}')
      .join('\n') + '\n';
  
  // For Lambda URLs, path is always "/" and query is empty
  final canonicalRequest = [
    method,
    '/',
    '', // Empty query string
    canonicalHeadersStr,
    signedHeaders,
    sha256.convert(utf8.encode(body)).toString(),
  ].join('\n');
  
  print('\n=== CANONICAL REQUEST ===');
  print(canonicalRequest);
  
  // Step 2: Create string to sign
  final credentialScope = '$date/$region/$service/aws4_request';
  final stringToSign = [
    'AWS4-HMAC-SHA256',
    dateTime,
    credentialScope,
    sha256.convert(utf8.encode(canonicalRequest)).toString(),
  ].join('\n');
  
  print('\n=== STRING TO SIGN ===');
  print(stringToSign);
  
  // Step 3: Calculate signature
  final kDate = _hmacSha256(utf8.encode('AWS4$secretKey'), utf8.encode(date));
  final kRegion = _hmacSha256(kDate, utf8.encode(region));
  final kService = _hmacSha256(kRegion, utf8.encode(service));
  final kSigning = _hmacSha256(kService, utf8.encode('aws4_request'));
  final signature = _hmacSha256(kSigning, utf8.encode(stringToSign));
  
  final signatureHex = signature.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  
  // Step 4: Add authorization header
  final authorization = 'AWS4-HMAC-SHA256 '
      'Credential=$accessKey/$credentialScope, '
      'SignedHeaders=$signedHeaders, '
      'Signature=$signatureHex';
  
  print('\n=== AUTHORIZATION ===');
  print(authorization);
  
  return {
    ...headers,
    'Authorization': authorization,
  };
}

List<int> _hmacSha256(List<int> key, List<int> data) {
  final hmac = Hmac(sha256, key);
  return hmac.convert(data).bytes;
}