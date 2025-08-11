import 'package:flutter/material.dart';
import '../services/supabase_auth_service.dart';
import 'password_recovery_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SupabaseLoginScreen extends StatefulWidget {
  const SupabaseLoginScreen({super.key});

  @override
  State<SupabaseLoginScreen> createState() => _SupabaseLoginScreenState();
}

class _SupabaseLoginScreenState extends State<SupabaseLoginScreen> {
  final SupabaseAuthService _authService = SupabaseAuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSignUpMode = false;
  bool _showOtpInput = false;
  bool _obscurePassword = true;
  String? _pendingPhone;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
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

  Future<void> _signInWithEmail() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showError('Please enter both email and password');
      return;
    }

    _setLoading(true);
    try {
      final result = await _authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      
      if (result != null && result.user != null) {
        // Success - navigation will be handled by auth state listener
        print('Email Sign In successful: ${result.user?.email}');
      } else {
        _showError('Sign in failed');
      }
    } catch (e) {
      _showError('Sign in failed: ${e.toString()}');
    }
  }

  Future<void> _signUpWithEmail() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showError('Please enter both email and password');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    _setLoading(true);
    try {
      final result = await _authService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      
      if (result != null && result.user != null) {
        // Check if email confirmation is needed
        if (result.user?.emailConfirmedAt == null) {
          _showError('Please check your email to confirm your account');
        } else {
          print('Email Sign Up successful: ${result.user?.email}');
        }
      } else {
        _showError('Sign up failed');
      }
    } catch (e) {
      _showError('Sign up failed: ${e.toString()}');
    }
  }

  Future<void> _signInWithApple() async {
    _setLoading(true);
    try {
      final result = await _authService.signInWithApple();
      if (result != null && result.user != null) {
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
      if (result != null && result.user != null) {
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
      onSuccess: (message) {
        setState(() {
          _pendingPhone = phoneNumber;
          _showOtpInput = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      },
      onError: (error) {
        _showError(error);
      },
    );
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().isEmpty) {
      _showError('Please enter the verification code');
      return;
    }

    if (_pendingPhone == null) {
      _showError('Phone number is missing. Please try again.');
      return;
    }

    _setLoading(true);
    try {
      final result = await _authService.verifyPhoneOtp(
        _pendingPhone!,
        _otpController.text.trim(),
      );
      
      if (result != null && result.user != null) {
        // Success - navigation will be handled by auth state listener
        print('Phone verification successful: ${result.user?.phone}');
      } else {
        _showError('Invalid verification code');
      }
    } catch (e) {
      _showError('Verification failed: ${e.toString()}');
    }
  }

  void _resetPhoneAuth() {
    setState(() {
      _showOtpInput = false;
      _pendingPhone = null;
      _otpController.clear();
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
                Text(
                  'Powered by Supabase 🚀\nSign in to save tickets and get win notifications!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
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

                // Email authentication form
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'your@email.com',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Forgot Password link (only show in sign in mode)
                if (!_isSignUpMode)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PasswordRecoveryScreen(),
                          ),
                        );
                      },
                      child: Text(
                        AppLocalizations.of(context)!.forgotPassword,
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),

                // Sign In / Sign Up button
                ElevatedButton(
                  onPressed: _isLoading ? null : (_isSignUpMode ? _signUpWithEmail : _signInWithEmail),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isSignUpMode ? 'Create Account' : 'Sign In'),
                ),
                const SizedBox(height: 12),

                // Toggle Sign In / Sign Up
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isSignUpMode = !_isSignUpMode;
                      _errorMessage = null;
                    });
                  },
                  child: Text(
                    _isSignUpMode 
                      ? 'Already have an account? Sign in'
                      : 'Don\'t have an account? Sign up',
                    style: const TextStyle(color: Colors.blue),
                  ),
                ),

                const SizedBox(height: 20),
                Text(
                  'Other sign-in options (coming soon)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Apple Sign In button (disabled for now)
                ElevatedButton.icon(
                  onPressed: null, // Disabled for now
                  icon: const Icon(Icons.apple, size: 24),
                  label: const Text('Continue with Apple (Setup required)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),

                // Google Sign In button (disabled for now)
                ElevatedButton.icon(
                  onPressed: null, // Disabled for now
                  icon: const Icon(Icons.g_mobiledata, size: 24),
                  label: const Text('Continue with Google (Setup required)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

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