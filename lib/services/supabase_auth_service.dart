import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:google_sign_in/google_sign_in.dart';  // Temporarily removed due to ML Kit conflict
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SupabaseAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  // final GoogleSignIn _googleSignIn = GoogleSignIn(  // Temporarily removed
  //   serverClientId: '', // We'll set this up later
  // );

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Stream of auth changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Sign up with email and password
  Future<AuthResponse?> signUpWithEmail(String email, String password) async {
    try {
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      return authResponse;
    } catch (e) {
      print('Email Sign Up Error: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<AuthResponse?> signInWithEmail(String email, String password) async {
    try {
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return authResponse;
    } catch (e) {
      print('Email Sign In Error: $e');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      print('Password Reset Error: $e');
      rethrow;
    }
  }

  // Sign in with Apple
  Future<AuthResponse?> signInWithApple() async {
    try {
      // Check if Sign in with Apple is available
      if (!await SignInWithApple.isAvailable()) {
        throw Exception('Sign in with Apple is not available on this device');
      }

      // Request Apple ID credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Sign in to Supabase with Apple credential
      final authResponse = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: appleCredential.identityToken!,
        accessToken: appleCredential.authorizationCode,
      );

      // Update display name if available and not already set
      if (authResponse.user != null && 
          authResponse.user!.userMetadata?['full_name'] == null &&
          appleCredential.givenName != null) {
        final displayName = '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim();
        await _supabase.auth.updateUser(
          UserAttributes(data: {'full_name': displayName}),
        );
      }

      return authResponse;
    } catch (e) {
      print('Apple Sign In Error: $e');
      rethrow;
    }
  }

  // Sign in with Google - TEMPORARILY DISABLED
  Future<AuthResponse?> signInWithGoogle() async {
    throw Exception('Google Sign In temporarily disabled due to dependency conflicts');
    /*
    try {
      // Start the sign-in process
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null || googleAuth.accessToken == null) {
        throw Exception('Failed to get Google authentication tokens');
      }

      // Sign in to Supabase with Google credential
      final authResponse = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken!,
      );

      return authResponse;
    } catch (e) {
      print('Google Sign In Error: $e');
      rethrow;
    }
    */
  }

  // Sign in with phone number (OTP)
  Future<void> signInWithPhoneNumber(
    String phoneNumber,
    {required Function(String message) onSuccess,
     required Function(String error) onError}
  ) async {
    try {
      await _supabase.auth.signInWithOtp(
        phone: phoneNumber,
      );
      onSuccess('Verification code sent to $phoneNumber');
    } catch (e) {
      onError(e.toString());
    }
  }

  // Verify phone OTP
  Future<AuthResponse?> verifyPhoneOtp(String phone, String token) async {
    try {
      final authResponse = await _supabase.auth.verifyOTP(
        type: OtpType.sms,
        phone: phone,
        token: token,
      );
      return authResponse;
    } catch (e) {
      print('Phone Verification Error: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Google if signed in - TEMPORARILY DISABLED
      // if (await _googleSignIn.isSignedIn()) {
      //   await _googleSignIn.signOut();
      // }
      
      // Sign out from Supabase
      await _supabase.auth.signOut();
    } catch (e) {
      print('Sign Out Error: $e');
      rethrow;
    }
  }

  // Delete account
  Future<bool> deleteAccount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // Note: Account deletion in Supabase requires admin privileges
        // For now, we'll just sign out. You can implement server-side deletion.
        await signOut();
        return true;
      }
      return false;
    } catch (e) {
      print('Delete Account Error: $e');
      rethrow;
    }
  }

  // Update profile
  Future<bool> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final updates = <String, dynamic>{};
        if (displayName != null) updates['full_name'] = displayName;
        if (photoURL != null) updates['avatar_url'] = photoURL;
        
        if (updates.isNotEmpty) {
          await _supabase.auth.updateUser(
            UserAttributes(data: updates),
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Update Profile Error: $e');
      rethrow;
    }
  }

  // Get user data for backend storage
  Map<String, dynamic>? getUserData() {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    return {
      'uid': user.id,
      'email': user.email,
      'phone': user.phone,
      'full_name': user.userMetadata?['full_name'],
      'avatar_url': user.userMetadata?['avatar_url'],
      'email_confirmed': user.emailConfirmedAt != null,
      'phone_confirmed': user.phoneConfirmedAt != null,
      'created_at': user.createdAt,
      'last_sign_in': user.lastSignInAt,
      'provider': user.appMetadata['provider'],
    };
  }

  // Initialize Supabase (call this in main())
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
}