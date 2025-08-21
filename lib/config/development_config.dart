// Development configuration for Xo So Lottery App
class DevelopmentConfig {
  // Supabase Development Configuration
  static const String supabaseUrl = 'https://bzugvwthyycszhohetlc.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ6dWd2d3RoeXljc3pob2hldGxjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzMDQyNTQsImV4cCI6MjA2OTg4MDI1NH0.CIluaTZ6sgEugrsftY6iCVyXXoqOFH-vUOi3Rh_vAfc';
  
  // AWS Development Configuration (Singapore region)
  static const String awsRegion = 'ap-southeast-1';
  static const String apiGatewayBaseUrl = 'https://408cu08m5i.execute-api.ap-southeast-1.amazonaws.com';
  static const String cognitoIdentityPoolId = 'ap-southeast-1:9728af83-62a8-410f-a585-53de188a5079';
  static const String s3BucketName = 'xoso-dev-ticket-images';
  
  // App Configuration
  static const String appDisplayName = 'Xo So (Dev)';
  static const String bundleId = 'com.cdawson.xoso.dev';
  
  // OAuth Configuration
  static const String googleOAuthRedirect = 'com.cdawson.xoso.dev://login-callback';
}