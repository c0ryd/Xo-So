import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  
  bool _isLoading = false;
  bool _showCodeInput = false;
  String? _verificationId;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _setLoading(bool loading) {
    setState(() {
      _isLoading = loading;
      if (loading) _errorMessage = null;
    });
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  Future<void> _signInWithApple() async {
    _setLoading(true);
    try {
      final result = await _authService.signInWithApple();
      if (result != null) {
        // Success - navigation will be handled by auth state listener
        print('Apple Sign In successful: ${result.user?.email}');
      } else {
        _showError('Apple Sign In was cancelled');
      }
    } catch (e) {
      _showError('Apple Sign In failed: ${e.toString()}');
    }
  }

  Future<void> _signInWithGoogle() async {
    _setLoading(true);
    try {
      final result = await _authService.signInWithGoogle();
      if (result != null) {
        // Success - navigation will be handled by auth state listener
        print('Google Sign In successful: ${result.user?.email}');
      } else {
        _showError('Google Sign In was cancelled');
      }
    } catch (e) {
      _showError('Google Sign In failed: ${e.toString()}');
    }
  }

  Future<void> _signInWithPhone() async {
    if (_phoneController.text.trim().isEmpty) {
      _showError('Please enter your phone number');
      return;
    }

    _setLoading(true);
    
    String phoneNumber = _phoneController.text.trim();
    // Add country code if not present
    if (!phoneNumber.startsWith('+')) {
      phoneNumber = '+1$phoneNumber'; // Default to US, you can make this configurable
    }

    await _authService.signInWithPhoneNumber(
      phoneNumber,
      onCodeSent: (verificationId) {
        setState(() {
          _verificationId = verificationId;
          _showCodeInput = true;
          _isLoading = false;
        });
      },
      onError: (error) {
        _showError(error);
      },
      onAutoVerificationCompleted: () {
        // Auto-verification successful (Android only)
        print('Phone Sign In auto-verified');
      },
    );
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().isEmpty) {
      _showError('Please enter the verification code');
      return;
    }

    if (_verificationId == null) {
      _showError('Verification ID is missing. Please try again.');
      return;
    }

    _setLoading(true);
    try {
      final result = await _authService.verifyPhoneCode(
        _verificationId!,
        _codeController.text.trim(),
      );
      
      if (result != null) {
        // Success - navigation will be handled by auth state listener
        print('Phone verification successful: ${result.user?.phoneNumber}');
      } else {
        _showError('Invalid verification code');
      }
    } catch (e) {
      _showError('Verification failed: ${e.toString()}');
    }
  }

  void _resetPhoneAuth() {
    setState(() {
      _showCodeInput = false;
      _verificationId = null;
      _codeController.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                         MediaQuery.of(context).padding.top - 
                         MediaQuery.of(context).padding.bottom - 48,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Logo/Title
                const Icon(
                  Icons.camera_alt,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Vietnamese Lottery OCR',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to save your tickets and get notified of wins!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red[200]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[700]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Phone number authentication
                if (!_showCodeInput) ...[
                  // Phone number input
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '+1 (555) 123-4567',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Phone sign in button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signInWithPhone,
                    icon: _isLoading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sms),
                    label: Text(_isLoading ? 'Sending...' : 'Sign in with Phone'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ] else ...[
                  // SMS code input
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Verification Code',
                      hintText: '123456',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _verifyCode,
                          icon: _isLoading 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check),
                          label: Text(_isLoading ? 'Verifying...' : 'Verify'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _resetPhoneAuth,
                        child: const Text('Change Number'),
                      ),
                    ],
                  ),
                ],

                if (!_showCodeInput) ...[
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR', style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Apple Sign In button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signInWithApple,
                    icon: const Icon(Icons.apple, size: 24),
                    label: const Text('Continue with Apple'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Google Sign In button - TEMPORARILY DISABLED
                  // ElevatedButton.icon(
                  //   onPressed: _isLoading ? null : _signInWithGoogle,
                  //   icon: const Icon(Icons.g_mobiledata, size: 24, color: Colors.blue),
                  //   label: const Text('Continue with Google'),
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: Colors.white,
                  //     foregroundColor: Colors.black87,
                  //     side: const BorderSide(color: Colors.grey),
                  //     padding: const EdgeInsets.symmetric(vertical: 16),
                  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  //   ),
                  // ),
                ],

                const SizedBox(height: 32),
                
                // Skip login option
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}