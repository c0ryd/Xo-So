# 📱 Dual Deployment Guide

This guide helps you maintain both **TestFlight** (production) and **Development** versions on the same device.

## 🎯 **Two App Versions**

| Version | Bundle ID | Display Name | Use Case |
|---------|-----------|--------------|----------|
| **Production** | `com.cdawson.xoso` | "Xo So" | TestFlight/App Store |
| **Development** | `com.cdawson.xoso.dev` | "Xo So Dev" | Xcode deployment |

## 🔧 **Quick Commands**

### **Switch to Development Mode**
```bash
bash scripts/configure_dev_build.sh
flutter clean && flutter pub get
flutter run -d [DEVICE_ID]
```

### **Switch to Production Mode** 
```bash
bash scripts/configure_prod_build.sh
flutter clean && flutter pub get
flutter build ios --release
# Then archive in Xcode for TestFlight
```

## 📋 **Complete Workflow**

### **1. Daily Development** (At Your Desk)
```bash
# Switch to dev mode
bash scripts/configure_dev_build.sh

# Deploy to device
flutter run -d 00008120-0016696E0240C01E

# App appears as "Xo So Dev" with different icon
```

### **2. TestFlight Release** (For Testing/Production)
```bash
# Switch to production mode
bash scripts/configure_prod_build.sh

# Build for release
flutter build ios --release

# Open in Xcode and archive
open ios/Runner.xcworkspace

# Upload to TestFlight through Xcode
```

## ⚙️ **Supabase Configuration**

You'll need to add the development redirect URL to your Supabase project:

1. Go to [Supabase Dashboard](https://supabase.com/dashboard/project/bzugvwthyycszhohetlc/auth/url-configuration)
2. Add to **Redirect URLs**:
   ```
   com.cdawson.xoso.dev://login-callback
   ```
3. Keep the existing production URL:
   ```
   com.cdawson.xoso://login-callback
   ```

## 🚨 **Important Notes**

### **Data Separation**
- Both apps share the same **Supabase backend** 
- Both apps share the same **AWS Lambda functions**
- Local data (images, preferences) are **separate** per app

### **OAuth Considerations**
- Google/Apple OAuth will work for both versions
- Each version has its own deep link scheme
- Supabase handles both redirect URLs automatically

### **Certificate Management**
- Development uses automatic signing
- Production uses distribution certificates
- Xcode manages this automatically

## 🎨 **Visual Differences**

| Feature | Production | Development |
|---------|------------|-------------|
| App Name | "Xo So" | "Xo So Dev" |
| Bundle ID | `com.cdawson.xoso` | `com.cdawson.xoso.dev` |
| Icon | Standard | Same (could be customized) |
| Deep Links | `com.cdawson.xoso://` | `com.cdawson.xoso.dev://` |

## 🔄 **Switching Between Modes**

The scripts automatically update:
- ✅ Bundle identifiers (iOS & Android)
- ✅ App display names
- ✅ Deep link schemes  
- ✅ OAuth redirect URLs
- ✅ Android manifest settings

## 📤 **Deployment Checklist**

### **Development Deploy**
- [ ] Run `bash scripts/configure_dev_build.sh`
- [ ] Run `flutter clean && flutter pub get`
- [ ] Deploy with `flutter run -d [DEVICE_ID]`
- [ ] App appears as "Xo So Dev"

### **TestFlight Deploy**  
- [ ] Run `bash scripts/configure_prod_build.sh`
- [ ] Run `flutter clean && flutter pub get`
- [ ] Build with `flutter build ios --release`
- [ ] Archive in Xcode
- [ ] Upload to TestFlight
- [ ] App appears as "Xo So"

## 🎉 **Benefits**

✅ **Both apps on same device** - No more Xcode expiration issues  
✅ **Easy switching** - One command to change modes  
✅ **Production safety** - TestFlight version always stable  
✅ **Development freedom** - Iterate quickly without affecting daily use  
✅ **Same backend** - All data synced between versions

