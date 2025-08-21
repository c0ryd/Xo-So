import 'package:flutter/foundation.dart';

class DebugLogger {
  static const String _prefix = '🔍 DEBUG';
  
  static void log(String message, {String? category, bool forceLog = false}) {
    if (kDebugMode || forceLog) {
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      final categoryPrefix = category != null ? '[$category] ' : '';
      print('$_prefix [$timestamp] $categoryPrefix$message');
    }
  }
  
  static void logAPI(String endpoint, Map<String, dynamic> payload, {String? category}) {
    log('📡 API CALL: $endpoint', category: category ?? 'API');
    log('📤 PAYLOAD: ${_formatJson(payload)}', category: category ?? 'API');
  }
  
  static void logAPIResponse(String endpoint, int statusCode, String response, {String? category}) {
    final icon = statusCode == 200 ? '✅' : '❌';
    log('$icon API RESPONSE: $endpoint - Status: $statusCode', category: category ?? 'API');
    log('📥 RESPONSE: ${_truncateResponse(response)}', category: category ?? 'API');
  }
  
  static void logError(String error, {String? category, StackTrace? stackTrace}) {
    log('❌ ERROR: $error', category: category ?? 'ERROR');
    if (stackTrace != null && kDebugMode) {
      log('📍 STACK: ${stackTrace.toString().split('\n').take(3).join('\n')}', category: category ?? 'ERROR');
    }
  }
  
  static void logSuccess(String message, {String? category}) {
    log('✅ SUCCESS: $message', category: category ?? 'SUCCESS');
  }
  
  static void logWarning(String message, {String? category}) {
    log('⚠️ WARNING: $message', category: category ?? 'WARNING');
  }
  
  static void logUserAction(String action, {Map<String, dynamic>? data}) {
    log('👤 USER ACTION: $action', category: 'USER');
    if (data != null) {
      log('📋 DATA: ${_formatJson(data)}', category: 'USER');
    }
  }
  
  static void logConfig(String key, dynamic value) {
    log('⚙️ CONFIG: $key = $value', category: 'CONFIG');
  }
  
  static void logDatabaseOperation(String operation, Map<String, dynamic>? data) {
    log('🗄️ DB: $operation', category: 'DATABASE');
    if (data != null) {
      log('📊 DATA: ${_formatJson(data)}', category: 'DATABASE');
    }
  }
  
  static String _formatJson(Map<String, dynamic> json) {
    try {
      return json.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    } catch (e) {
      return json.toString();
    }
  }
  
  static String _truncateResponse(String response) {
    if (response.length <= 200) return response;
    return '${response.substring(0, 200)}... (truncated)';
  }
  
  // Log current app configuration
  static void logCurrentConfig() {
    log('=== CURRENT APP CONFIGURATION ===', category: 'CONFIG');
    // Will be filled by AppConfig.printCurrentConfig()
  }
}
