import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';  // Temporarily disabled
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // final GoogleSignIn _googleSignIn = GoogleSignIn();  // Temporarily disabled

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Apple
  Future<UserCredential?> signInWithApple() async {
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

      // Create OAuth credential
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      
      // Update display name if available and not already set
      if (userCredential.user != null && 
          userCredential.user!.displayName == null &&
          appleCredential.givenName != null) {
        final displayName = '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim();
        await userCredential.user!.updateDisplayName(displayName);
      }

      return userCredential;
    } catch (e) {
      print('Apple Sign In Error: $e');
      rethrow;
    }
  }

  // Sign in with Google - TEMPORARILY DISABLED
  Future<UserCredential?> signInWithGoogle() async {
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

      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Google Sign In Error: $e');
      rethrow;
    }
    */
  }

  // Sign in with phone number
  Future<void> signInWithPhoneNumber(
    String phoneNumber,
    {required Function(String verificationId) onCodeSent,
     required Function(String error) onError,
     required Function() onAutoVerificationCompleted}
  ) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android only)
          await _auth.signInWithCredential(credential);
          onAutoVerificationCompleted();
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Phone verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Auto-retrieval timeout
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  // Verify phone code
  Future<UserCredential?> verifyPhoneCode(String verificationId, String smsCode) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth.signInWithCredential(credential);
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
      
      // Sign out from Firebase
      await _auth.signOut();
    } catch (e) {
      print('Sign Out Error: $e');
      rethrow;
    }
  }

  // Delete account
  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
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
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        if (photoURL != null) {
          await user.updatePhotoURL(photoURL);
        }
        await user.reload();
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
    final user = _auth.currentUser;
    if (user == null) return null;

    return {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'phoneNumber': user.phoneNumber,
      'photoURL': user.photoURL,
      'emailVerified': user.emailVerified,
      'createdAt': user.metadata.creationTime?.toIso8601String(),
      'lastSignIn': user.metadata.lastSignInTime?.toIso8601String(),
    };
  }
}