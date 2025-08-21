// Production configuration for Xo So Lottery App
class ProductionConfig {
  // Supabase Production Configuration
  static const String supabaseUrl = 'https://wmafxwddmorgwribclpm.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndtYWZ4d2RkbW9yZ3dyaWJjbHBtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU2Njk4MDMsImV4cCI6MjA3MTI0NTgwM30.4gfNVD-ozGxGLTl6ek7Dyl8_BgH0T7SBjZC4DSmC55A';
  
  // AWS Production Configuration (Singapore region)
  static const String awsRegion = 'ap-southeast-1';
  static const String apiGatewayBaseUrl = 'https://1u2oegojt3.execute-api.ap-southeast-1.amazonaws.com';
  static const String cognitoIdentityPoolId = 'ap-southeast-1:5835e33e-48f5-4e27-b3ab-556348346a1e';
  static const String s3BucketName = 'xoso-prod-ticket-images';
  
  // App Configuration
  static const String appDisplayName = 'Xo So';
  static const String bundleId = 'com.cdawson.xoso';
  static const String googleOAuthRedirect = 'com.cdawson.xoso://login-callback';
  
  // Feature Flags
  static const bool isProduction = true;
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;
  static const bool enableDebugLogging = false;
}


