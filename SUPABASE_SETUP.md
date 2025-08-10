# 🚀 Supabase Setup Guide

## Step 1: Create Supabase Project (2 minutes)

1. **Go to** [supabase.com](https://supabase.com)
2. **Sign up/Login** with GitHub (recommended)
3. **Click "New Project"**
4. **Choose your organization** (or create one)
5. **Fill out project details:**
   - Name: `Vietnamese Lottery OCR`
   - Database Password: `Create a strong password`
   - Region: `Southeast Asia (Singapore)` (closest to Vietnam)
   - Pricing Plan: `Free` (perfect for starting)
6. **Click "Create new project"**
7. **Wait 2-3 minutes** for project to be ready

## Step 2: Get Your Credentials (30 seconds)

1. **Go to** Settings → API
2. **Copy these values:**
   - Project URL: `https://xxxxx.supabase.co`
   - API Key (anon/public): `eyJhbG...` (long string)

## Step 3: Enable Authentication Providers (2 minutes)

1. **Go to** Authentication → Providers
2. **Enable these providers:**

### Phone Authentication (Recommended - works everywhere)
   - **Toggle ON** "Phone"
   - **SMS Provider:** Twilio (free tier includes credits)
   - **You'll need Twilio later, but enable it now**

### Apple Sign In
   - **Toggle ON** "Apple"
   - **Service ID:** `com.cdawson.xoso.signin` (or your bundle ID + `.signin`)
   - **Team ID & Key ID:** Get from Apple Developer Console
   - **Private Key:** Get from Apple Developer Console

### Google Sign In  
   - **Toggle ON** "Google"
   - **Client ID & Secret:** Get from Google Cloud Console
   - **We'll set this up next**

## Step 4: Update Flutter App (30 seconds)

Replace the credentials in `lib/main_supabase.dart`:

```dart
const String SUPABASE_URL = 'https://YOUR_PROJECT_ID.supabase.co';
const String SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

## Step 5: Test Phone Authentication (1 minute)

1. **Run the app:** `flutter run -d YOUR_DEVICE_ID -t lib/main_supabase.dart`
2. **Try phone authentication** (it will show an error about Twilio, which is normal)
3. **Verify the UI works correctly**

## Next Steps After Basic Setup:

- **Set up Twilio** for SMS (if you want phone auth)
- **Set up Google OAuth** (if you want Google Sign In)
- **Set up Apple Sign In** (if you want Apple Sign In)
- **Add user database tables** (for storing lottery tickets)

---

## 🔥 Why Supabase is Better Than Firebase:

✅ **No iOS build issues with Xcode 16**  
✅ **Cleaner authentication APIs**  
✅ **Built-in database (PostgreSQL)**  
✅ **Real-time subscriptions**  
✅ **Better pricing (more generous free tier)**  
✅ **Open source (you can self-host)**  
✅ **Better documentation**  
✅ **Row Level Security built-in**  

Ready to set up your project? Let me know when you've completed Step 1-2!