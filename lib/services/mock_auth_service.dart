// Mock authentication service for demo purposes
// This simulates Firebase Auth without Firebase dependencies

class MockUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoURL;
  final bool emailVerified;
  final DateTime? creationTime;

  MockUser({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.photoURL,
    this.emailVerified = false,
    this.creationTime,
  });
}

class MockUserCredential {
  final MockUser user;
  MockUserCredential(this.user);
}

class MockAuthService {
  MockUser? _currentUser;
  final List<Function(MockUser?)> _listeners = [];

  // Get current user
  MockUser? get currentUser => _currentUser;

  // Stream of auth changes (simplified)
  Stream<MockUser?> get authStateChanges async* {
    yield _currentUser;
    // In real implementation, this would be a proper stream
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener(_currentUser);
    }
  }

  // Mock Apple Sign In
  Future<MockUserCredential?> signInWithApple() async {
    print('🍎 Mock Apple Sign In - showing native Apple dialog...');
    
    // Simulate network delay
    await Future.delayed(Duration(seconds: 1));
    
    // Create mock user (in real life, this comes from Apple)
    final user = MockUser(
      uid: 'apple_${DateTime.now().millisecondsSinceEpoch}',
      email: 'user@privaterelay.appleid.com',
      displayName: 'Apple User',
      emailVerified: true,
      creationTime: DateTime.now(),
    );
    
    _currentUser = user;
    _notifyListeners();
    
    print('✅ Apple Sign In successful: ${user.email}');
    return MockUserCredential(user);
  }

  // Mock Google Sign In
  Future<MockUserCredential?> signInWithGoogle() async {
    print('🔍 Mock Google Sign In - showing Google account picker...');
    
    // Simulate network delay
    await Future.delayed(Duration(seconds: 1));
    
    // Create mock user (in real life, this comes from Google)
    final user = MockUser(
      uid: 'google_${DateTime.now().millisecondsSinceEpoch}',
      email: 'user@gmail.com',
      displayName: 'Google User',
      photoURL: 'https://lh3.googleusercontent.com/a/default-user=s96-c',
      emailVerified: true,
      creationTime: DateTime.now(),
    );
    
    _currentUser = user;
    _notifyListeners();
    
    print('✅ Google Sign In successful: ${user.email}');
    return MockUserCredential(user);
  }

  // Mock Phone Number Authentication
  Future<void> signInWithPhoneNumber(
    String phoneNumber,
    {required Function(String verificationId) onCodeSent,
     required Function(String error) onError,
     required Function() onAutoVerificationCompleted}
  ) async {
    print('📱 Mock Phone Auth - sending SMS to $phoneNumber...');
    
    try {
      // Simulate sending SMS
      await Future.delayed(Duration(seconds: 1));
      
      // Mock verification ID
      final verificationId = 'mock_verification_${DateTime.now().millisecondsSinceEpoch}';
      onCodeSent(verificationId);
      
      print('✅ Mock SMS sent with verification ID: $verificationId');
    } catch (e) {
      onError('Mock error: Failed to send SMS');
    }
  }

  // Mock verify phone code
  Future<MockUserCredential?> verifyPhoneCode(String verificationId, String smsCode) async {
    print('📱 Mock Phone Verification - verifying code $smsCode...');
    
    // Simulate verification delay
    await Future.delayed(Duration(milliseconds: 500));
    
    // Simple mock validation (in real life, this goes to Firebase)
    if (smsCode == '123456' || smsCode.length == 6) {
      // Create mock user
      final user = MockUser(
        uid: 'phone_${DateTime.now().millisecondsSinceEpoch}',
        phoneNumber: '+1 (555) 123-4567', // Mock phone number
        displayName: 'Phone User',
        emailVerified: false,
        creationTime: DateTime.now(),
      );
      
      _currentUser = user;
      _notifyListeners();
      
      print('✅ Phone verification successful: ${user.phoneNumber}');
      return MockUserCredential(user);
    } else {
      print('❌ Mock verification failed - invalid code');
      return null;
    }
  }

  // Mock sign out
  Future<void> signOut() async {
    print('👋 Mock Sign Out');
    _currentUser = null;
    _notifyListeners();
  }

  // Mock delete account
  Future<bool> deleteAccount() async {
    print('🗑️ Mock Delete Account');
    _currentUser = null;
    _notifyListeners();
    return true;
  }

  // Mock update profile
  Future<bool> updateProfile({String? displayName, String? photoURL}) async {
    if (_currentUser != null) {
      print('📝 Mock Update Profile: $displayName, $photoURL');
      // In real implementation, we'd update the user object
      return true;
    }
    return false;
  }

  // Get user data for backend storage
  Map<String, dynamic>? getUserData() {
    final user = _currentUser;
    if (user == null) return null;

    return {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'phoneNumber': user.phoneNumber,
      'photoURL': user.photoURL,
      'emailVerified': user.emailVerified,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}