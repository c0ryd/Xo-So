#!/bin/bash

# Configure app for development build with different bundle ID
# This allows both TestFlight and development versions on the same device

echo "🔧 Configuring development build..."

# Update iOS bundle identifier
sed -i '' 's/com\.cdawson\.xoso/com.cdawson.xoso.dev/g' ios/Runner.xcodeproj/project.pbxproj

# Update Android application ID
sed -i '' 's/applicationId = "com\.cdawson\.xoso"/applicationId = "com.cdawson.xoso.dev"/g' android/app/build.gradle

# Update display name for development
sed -i '' 's/<string>Xo So<\/string>/<string>Xo So Dev<\/string>/g' ios/Runner/Info.plist

# Update Android app name
if [ -f "android/app/src/main/res/values/strings.xml" ]; then
    sed -i '' 's/<string name="app_name">.*<\/string>/<string name="app_name">Xo So Dev<\/string>/g' android/app/src/main/res/values/strings.xml
fi

# Update Supabase redirect URL for development
sed -i '' 's/com\.cdawson\.xoso:\/\/login-callback/com.cdawson.xoso.dev:\/\/login-callback/g' lib/services/supabase_auth_service.dart
sed -i '' 's/com\.cdawson\.xoso:\/\/login-callback/com.cdawson.xoso.dev:\/\/login-callback/g' lib/main.dart

# Update Android manifest for deep links
sed -i '' 's/android:scheme="com\.cdawson\.xoso"/android:scheme="com.cdawson.xoso.dev"/g' android/app/src/main/AndroidManifest.xml

# Update iOS URL scheme
sed -i '' 's/<string>com\.cdawson\.xoso<\/string>/<string>com.cdawson.xoso.dev<\/string>/g' ios/Runner/Info.plist

echo "✅ Development build configured!"
echo "📱 Bundle ID: com.cdawson.xoso.dev"
echo "📱 Display Name: Xo So Dev"
echo "🔗 OAuth Redirect: com.cdawson.xoso.dev://login-callback"
echo ""
echo "ℹ️  You'll need to update Supabase OAuth settings to include the new redirect URL"
echo "ℹ️  Run 'bash scripts/configure_prod_build.sh' to switch back to production"

