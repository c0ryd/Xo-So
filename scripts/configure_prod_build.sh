#!/bin/bash

# Configure app for production build (TestFlight/App Store)
# Reverts development changes back to production settings

echo "🚀 Configuring production build..."

# Revert iOS bundle identifier
sed -i '' 's/com\.cdawson\.xoso\.dev/com.cdawson.xoso/g' ios/Runner.xcodeproj/project.pbxproj

# Revert Android application ID
sed -i '' 's/applicationId = "com\.cdawson\.xoso\.dev"/applicationId = "com.cdawson.xoso"/g' android/app/build.gradle

# Revert display name for production
sed -i '' 's/<string>Xo So Dev<\/string>/<string>Xo So<\/string>/g' ios/Runner/Info.plist

# Revert Android app name
if [ -f "android/app/src/main/res/values/strings.xml" ]; then
    sed -i '' 's/<string name="app_name">Xo So Dev<\/string>/<string name="app_name">Xo So<\/string>/g' android/app/src/main/res/values/strings.xml
fi

# Revert Supabase redirect URL for production
sed -i '' 's/com\.cdawson\.xoso\.dev:\/\/login-callback/com.cdawson.xoso:\/\/login-callback/g' lib/services/supabase_auth_service.dart
sed -i '' 's/com\.cdawson\.xoso\.dev:\/\/login-callback/com.cdawson.xoso:\/\/login-callback/g' lib/main.dart

# Revert Android manifest for deep links
sed -i '' 's/android:scheme="com\.cdawson\.xoso\.dev"/android:scheme="com.cdawson.xoso"/g' android/app/src/main/AndroidManifest.xml

# Revert iOS URL scheme
sed -i '' 's/<string>com\.cdawson\.xoso\.dev<\/string>/<string>com.cdawson.xoso<\/string>/g' ios/Runner/Info.plist

echo "✅ Production build configured!"
echo "📱 Bundle ID: com.cdawson.xoso"
echo "📱 Display Name: Xo So"
echo "🔗 OAuth Redirect: com.cdawson.xoso://login-callback"
echo ""
echo "📤 Ready for TestFlight/App Store submission"

