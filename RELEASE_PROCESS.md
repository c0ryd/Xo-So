# 🚀 Xo So Lottery App - Release Process

## 📋 Overview
This document outlines the complete process for releasing updates to the Xo So lottery app, from development through App Store deployment.

---

## 🔄 Development to Production Workflow

### Phase 1: Development & Testing

#### 1.1 Local Development
```bash
cd "/Users/cdawson/Desktop/Xo So"

# Run in debug mode (uses dev backend)
flutter run -d 00008120-0016696E0240C01E --debug
```

#### 1.2 Backend Development
```bash
cd aws

# Deploy changes to development environment
npm run deploy:dev

# Test dev APIs
curl -X POST "https://802ol1y5f4.execute-api.ap-southeast-1.amazonaws.com/dev/fetchResults" \
  -H "Content-Type: application/json" \
  -d '{"province":"Hà Nội","date":"2025-08-21"}'
```

#### 1.3 Frontend Development
- Make changes to `lib/` files
- Test with development backend (debug mode uses `DevelopmentConfig`)
- Verify all features work with dev data

---

### Phase 2: Production Preparation

#### 2.1 Backend Deployment to Production
```bash
cd aws

# Backup production data (CRITICAL for live app)
aws dynamodb create-backup --table-name xoso-tickets-prod --backup-name "backup-$(date +%Y%m%d-%H%M%S)"
aws dynamodb create-backup --table-name xoso-results-prod --backup-name "results-backup-$(date +%Y%m%d-%H%M%S)"

# Deploy backend to production
npm run deploy:prod

# ⚠️ IMPORTANT: Check if API Gateway URL changed in output
# Example: https://[NEW-ID].execute-api.ap-southeast-1.amazonaws.com/prod/
```

#### 2.2 Update Production Config (if API URL changed)
```bash
# Edit lib/config/production_config.dart
# Update apiGatewayBaseUrl if deployment created new API Gateway
static const String apiGatewayBaseUrl = 'https://[NEW-ID].execute-api.ap-southeast-1.amazonaws.com';
```

#### 2.3 Test Production APIs
```bash
# Verify all endpoints work
curl -X POST "https://[PROD-API-URL]/prod/fetchResults" \
  -H "Content-Type: application/json" \
  -d '{"province":"Hà Nội","date":"2025-08-21"}'

curl -X POST "https://[PROD-API-URL]/prod/processWinners" \
  -H "Content-Type: application/json" -d '{}'
```

---

### Phase 3: iOS App Release

#### 3.1 Pre-Build Verification
```bash
# Ensure production configuration is correct
# Check lib/config/app_config.dart:
# static bool get isProduction => kReleaseMode; // Should be kReleaseMode, not true

# Verify version numbers in pubspec.yaml
version: 1.0.0+1  # Update as needed
```

#### 3.2 Build Production IPA

**Option A: Command Line (Recommended)**
```bash
cd "/Users/cdawson/Desktop/Xo So"

# Clean previous builds
flutter clean
flutter pub get

# Build production IPA
flutter build ipa --release

# IPA location: build/ios/ipa/Runner.ipa
```

**Option B: Xcode**
```bash
# Open Xcode project
open ios/Runner.xcworkspace

# In Xcode:
# 1. Select "Any iOS Device" as target
# 2. Product → Archive
# 3. Wait for archive to complete
```

#### 3.3 Upload to App Store Connect

**Option A: Command Line**
```bash
# Upload via altool (requires app-specific password)
xcrun altool --upload-app --type ios \
  --file build/ios/ipa/Runner.ipa \
  --username your-apple-id@email.com \
  --password your-app-specific-password
```

**Option B: Xcode**
```bash
# After archiving in Xcode:
# 1. Click "Distribute App"
# 2. Select "App Store Connect"
# 3. Follow upload wizard
```

#### 3.4 TestFlight Configuration
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app
3. Go to TestFlight tab
4. Select the uploaded build
5. Add test information:
   - What to test
   - Version notes
   - Test details
6. Submit for Beta App Review (if first TestFlight build)
7. Add internal/external testers

---

## 📊 Monitoring & Rollback

### Production Monitoring
```bash
# Monitor Lambda function errors
aws logs tail /aws/lambda/xoso-prod-processWinners --follow

# Check DynamoDB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name UserErrors \
  --dimensions Name=TableName,Value=xoso-tickets-prod \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

### Emergency Rollback Plan
```bash
# If critical issues found:

# 1. Remove app from App Store (if necessary)
#    - Go to App Store Connect → App Store → Remove from Sale

# 2. Rollback backend (if backend issues)
cd aws
# Deploy previous version or specific function
npm run deploy:prod

# 3. Restore database (if data corruption)
aws dynamodb restore-table-from-backup \
  --source-backup-arn arn:aws:dynamodb:region:account:table/xoso-tickets-prod/backup/[backup-name] \
  --target-table-name xoso-tickets-prod-restored
```

---

## ✅ Release Checklist

### Pre-Release
- [ ] All features tested in development environment
- [ ] Backend deployed and tested in production
- [ ] Production config updated (if API URLs changed)
- [ ] Version number updated in `pubspec.yaml`
- [ ] Release notes prepared
- [ ] Data backups created

### Build & Upload
- [ ] Clean build completed successfully
- [ ] IPA uploaded to App Store Connect
- [ ] Build shows "Ready to Submit" status
- [ ] TestFlight configured with test information
- [ ] Internal testers added and notified

### Post-Release
- [ ] Monitor error rates for 24-48 hours
- [ ] Check user feedback in TestFlight
- [ ] Verify critical user flows work
- [ ] Monitor backend metrics (Lambda, DynamoDB)
- [ ] Check lottery result generation is working (cron jobs)

### App Store Submission (when ready)
- [ ] App metadata complete (description, keywords, screenshots)
- [ ] Privacy policy updated
- [ ] Content rating reviewed
- [ ] Pricing and availability set
- [ ] Submit for App Review

---

## 🚨 Critical Environments

### Development Environment
- **Supabase**: Development project
- **AWS API**: `https://802ol1y5f4.execute-api.ap-southeast-1.amazonaws.com/dev/`
- **DynamoDB**: `xoso-tickets-dev`, `xoso-results-dev`
- **S3**: `xoso-dev-ticket-images`
- **Bundle ID**: `com.cdawson.xoso.dev`

### Production Environment
- **Supabase**: Production project
- **AWS API**: `https://1u2oegojt3.execute-api.ap-southeast-1.amazonaws.com/prod/`
- **DynamoDB**: `xoso-tickets-prod`, `xoso-results-prod`
- **S3**: `xoso-prod-ticket-images`
- **Bundle ID**: `com.cdawson.xoso`

---

## 📞 Emergency Contacts

### AWS Account ID
`911167902662`

### Critical AWS Resources
- **Region**: `ap-southeast-1` (Singapore)
- **Cognito Identity Pools**:
  - Dev: `ap-southeast-1:9728af83-62a8-410f-a585-53de188a5079`
  - Prod: `ap-southeast-1:5835e33e-48f5-4e27-b3ab-556348346a1e`

### Apple Developer
- **Team ID**: `S69XJ274BR`
- **Bundle IDs**: 
  - Dev: `com.cdawson.xoso.dev`
  - Prod: `com.cdawson.xoso`

---

## 📅 Automated Processes

### Daily Cron Jobs (4:15 PM Vietnam Time)
- Generate lottery results for all provinces
- Process unchecked tickets
- Send push notifications to users
- Both dev and prod environments run independently

### Monitoring Schedule
- **Daily**: Check error rates and user feedback
- **Weekly**: Review backend metrics and costs
- **Monthly**: Audit user data and cleanup unused resources

---

*Last Updated: $(date)*
*Version: 1.0*
