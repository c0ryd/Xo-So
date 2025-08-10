# 🚀 Firebase Authentication Setup Guide

Your Vietnamese Lottery OCR app now includes a complete Firebase authentication system! Follow these steps to enable real authentication.

## ✅ What's Already Done

- ✅ Firebase authentication UI (Apple, Google, Phone)
- ✅ Scrollable login screen (no more overflows!)
- ✅ Real Firebase Auth integration
- ✅ User profile management
- ✅ Auth state management throughout the app

## 🔧 Required Setup Steps

### 1. Create Firebase Project (5 minutes)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `vietnamese-lottery-ocr`
4. Enable Google Analytics (recommended)
5. Wait for project creation

### 2. Enable Authentication Methods (3 minutes)

1. In Firebase Console, go to **Authentication > Sign-in method**
2. Enable these providers:
   - ✅ **Phone** (for SMS verification)
   - ✅ **Google** (for Google Sign In)
   - ✅ **Apple** (for Sign in with Apple)

### 3. Configure iOS App (5 minutes)

1. In Firebase Console, click "Add app" → iOS
2. iOS bundle ID: `com.cdawson.xoso`
3. Download `GoogleService-Info.plist`
4. **IMPORTANT:** Add the file to your Xcode project:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Drag `GoogleService-Info.plist` into `Runner/Runner` folder
   - ✅ Make sure "Add to target: Runner" is checked

### 4. Generate Firebase Configuration (2 minutes)

Run these commands in your terminal:

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for your project
flutterfire configure
```

This will:
- Generate `lib/firebase_options.dart` with your real config
- Replace the placeholder values automatically

### 5. Configure Apple Sign In (iOS only)

1. In Apple Developer Console:
   - Enable "Sign in with Apple" capability
   - Add your bundle ID to App IDs
2. In Xcode:
   - Select `Runner` target
   - Go to "Signing & Capabilities" 
   - Add "Sign in with Apple" capability

### 6. Configure Google Sign In

1. In Firebase Console → Authentication → Sign-in method → Google
2. Download the config file again (it includes Google Sign In config)
3. For iOS: The `GoogleService-Info.plist` already includes Google Sign In

### 7. Test Authentication (2 minutes)

1. Run the app: `flutter run -d your-device`
2. Try each sign-in method:
   - 📱 **Phone:** Use your real phone number
   - 🍎 **Apple:** Use your Apple ID  
   - 🔍 **Google:** Use your Google account

## 🎯 Expected User Flow

1. **App Launch:** User sees login screen
2. **Authentication:** User signs in with preferred method
3. **Main App:** User scans lottery tickets
4. **Profile:** User can view profile info in top-right menu
5. **Sign Out:** User can sign out and return to login

## 🔍 Troubleshooting

### "Firebase project not found"
- Make sure you ran `flutterfire configure`
- Check that `lib/firebase_options.dart` has real values (not placeholders)

### "Apple Sign In not available"
- Only works on real iOS devices (not simulator)
- Make sure Apple ID is set up on the device

### "Google Sign In failed"
- Make sure you downloaded the latest `GoogleService-Info.plist`
- Check that Google Sign In is enabled in Firebase Console

### "Phone verification failed"
- Phone verification has daily limits
- Make sure your phone number is in correct format: `+1234567890`

## 🚀 Next Steps (Future Features)

Once authentication is working, we can add:

1. **📱 Ticket Storage:** Save scanned tickets to Firebase Firestore
2. **🔔 Push Notifications:** Notify users when they win
3. **📊 Win History:** Track wins over time
4. **👥 User Management:** Admin features, user analytics

## 💡 Need Help?

If you run into issues:
1. Check the Firebase Console for error logs
2. Run `flutter clean && flutter pub get` to refresh dependencies
3. Make sure all files are properly added to Xcode project

---

**Ready to test?** Once you complete steps 1-4, run `flutter run` and try signing in! 🎉