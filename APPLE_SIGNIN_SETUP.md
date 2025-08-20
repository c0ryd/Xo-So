# 🍎 Apple Sign In Setup for Development Builds

## 🚨 **Current Issue**
Apple Sign In only works with registered App IDs. The development build (`com.cdawson.xoso.dev`) needs to be registered separately.

## 📋 **Apple Developer Console Setup**

### **Step 1: Create Development App ID**
1. Go to [Apple Developer Console](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles** → **Identifiers**
3. Click the **+** button to create a new identifier
4. Select **App IDs** → **App**
5. Configure:
   - **Bundle ID**: `com.cdawson.xoso.dev`
   - **Description**: "Xo So Development"
   - **Capabilities**: Enable "Sign In with Apple"

### **Step 2: Configure Sign In with Apple**
1. Find your existing App ID: `com.cdawson.xoso`
2. Edit it and ensure **Sign In with Apple** is enabled
3. Do the same for the new development App ID: `com.cdawson.xoso.dev`

### **Step 3: App-Specific Password (if needed)**
1. Go to [appleid.apple.com](https://appleid.apple.com/)
2. Sign in with your Apple ID
3. Navigate to **Sign-In and Security** → **App-Specific Passwords**
4. Generate a new password for your development app

## 🔄 **Alternative Solutions**

### **Option 1: Use Email/Password Login (Current)**
The development app currently shows:
- ❌ **Apple Sign In** - Disabled with helpful message
- ✅ **Google Sign In** - Works normally  
- ✅ **Email/Password** - Works normally
- ✅ **Phone/OTP** - Works normally

### **Option 2: Disable Apple Sign In for Dev Builds**
The current implementation automatically detects development builds and shows a helpful message explaining why Apple Sign In is disabled.

### **Option 3: Configure Both App IDs**
Follow the Apple Developer Console steps above to enable Apple Sign In for both bundle IDs.

## 🧪 **Testing**

### **Development Build** (`com.cdawson.xoso.dev`)
- Apple Sign In: Disabled with explanation
- Google Sign In: ✅ Works
- Email/Password: ✅ Works  
- Phone/OTP: ✅ Works

### **Production Build** (`com.cdawson.xoso`)
- Apple Sign In: ✅ Works
- Google Sign In: ✅ Works
- Email/Password: ✅ Works
- Phone/OTP: ✅ Works

## 💡 **Recommendation**

For development workflow, use **Google Sign In** or **Email/Password** since they work across both bundle IDs without additional configuration. This keeps your development process smooth while maintaining full Apple Sign In functionality in the production TestFlight build.

## 🔧 **Current Status**

✅ **Development app deployed** with helpful Apple Sign In message  
✅ **Alternative login methods** working in development  
✅ **Production app** maintains full Apple Sign In functionality  
✅ **Dual deployment** system working perfectly

