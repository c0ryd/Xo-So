import 'package:flutter/foundation.dart';
import 'development_config.dart';
import 'production_config.dart';

class AppConfig {
  static bool get isProduction => kReleaseMode;

  static String get supabaseUrl =>
      isProduction ? ProductionConfig.supabaseUrl : DevelopmentConfig.supabaseUrl;

  static String get supabaseAnonKey =>
      isProduction ? ProductionConfig.supabaseAnonKey : DevelopmentConfig.supabaseAnonKey;

  static String get awsRegion =>
      isProduction ? ProductionConfig.awsRegion : DevelopmentConfig.awsRegion;

  static String get apiGatewayBaseUrl =>
      isProduction ? ProductionConfig.apiGatewayBaseUrl : DevelopmentConfig.apiGatewayBaseUrl;

  static String get cognitoIdentityPoolId =>
      isProduction ? ProductionConfig.cognitoIdentityPoolId : DevelopmentConfig.cognitoIdentityPoolId;

  static String get s3BucketName =>
      isProduction ? ProductionConfig.s3BucketName : DevelopmentConfig.s3BucketName;

  static String get appDisplayName =>
      isProduction ? ProductionConfig.appDisplayName : DevelopmentConfig.appDisplayName;

  static String get bundleId =>
      isProduction ? ProductionConfig.bundleId : DevelopmentConfig.bundleId;

  static String get googleOAuthRedirect =>
      isProduction ? ProductionConfig.googleOAuthRedirect : DevelopmentConfig.googleOAuthRedirect;

  static void printCurrentConfig() {
    print('🏗️ APP CONFIG - Environment: ${isProduction ? "PRODUCTION" : "DEVELOPMENT"}');
    print('📊 Supabase URL: $supabaseUrl');
    print('🔗 API Gateway: $apiGatewayBaseUrl');
    print('📦 S3 Bucket: $s3BucketName');
    print('🔑 Cognito Pool ID: $cognitoIdentityPoolId');
    print('📍 AWS Region: $awsRegion');
    print('📱 Bundle ID: $bundleId');
    print('🌐 Google OAuth Redirect: $googleOAuthRedirect');
    print('=' * 60);
  }
}