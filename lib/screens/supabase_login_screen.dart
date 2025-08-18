import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_auth_service.dart';
import '../services/language_service.dart';
import 'home_screen.dart';
import '../widgets/vietnamese_tiled_background.dart';
import 'password_recovery_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

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
  bool _isPhoneMode = false; // Track if user is entering phone number
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _googleSignInTimeout;

  @override
  void initState() {
    super.initState();
    
    // Listen to email controller changes to detect phone vs email mode
    _emailController.addListener(_detectInputMode);
    
    // Listen to auth state changes to clear loading state when OAuth succeeds
    _authSubscription = _authService.authStateChanges.listen((AuthState authState) {
      if (mounted && authState.session != null) {
        // Authentication succeeded - clear loading state and timeout
        _googleSignInTimeout?.cancel();
        // The main AuthWrapper will handle navigation
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
        // Proactively navigate to Home to avoid waiting for sheet dismissal
        // If Home is already showing via AuthWrapper, this will be a no-op visually
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => HomeScreen()),
            (route) => false,
          );
        });
      }
    });
  }

  void _detectInputMode() {
    final text = _emailController.text;
    
    setState(() {
      if (text.isEmpty) {
        // Reset to email mode when field is empty
        _isPhoneMode = false;
      } else {
        final isNumeric = RegExp(r'^[0-9]*$').hasMatch(text);
        final hasEmailChar = text.contains('@') || RegExp(r'[a-zA-Z]').hasMatch(text);
        
        if (isNumeric) {
          _isPhoneMode = true;
        } else if (hasEmailChar) {
          _isPhoneMode = false;
        }
        // If text has mixed content, keep current mode
      }
    });
  }

  @override
  void dispose() {
    _emailController.removeListener(_detectInputMode);
    _authSubscription?.cancel();
    _googleSignInTimeout?.cancel();
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

  void _showError(String message, {bool isSuccess = false}) {
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  Future<void> _signInWithEmail() async {
    if (_isPhoneMode) {
      await _signInWithPhone();
      return;
    }

    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showError(AppLocalizations.of(context)!.pleaseEnterEmailPassword);
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
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _signUpWithEmail() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showError(AppLocalizations.of(context)!.pleaseEnterEmailPassword);
      return;
    }

    if (_passwordController.text.length < 6) {
      _showError(AppLocalizations.of(context)!.passwordMinLength);
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
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _signUpWithPhone() async {
    final phoneNumber = _emailController.text.trim();
    
    if (phoneNumber.isEmpty) {
      _showError('Please enter a phone number');
      return;
    }

    // Basic phone number validation - allow + at start, then digits
    if (!RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(phoneNumber)) {
      _showError('Please enter a valid phone number (include country code like +1234567890)');
      return;
    }

    _setLoading(true);
    try {
      await _authService.signInWithPhoneNumber(
        phoneNumber,
        onSuccess: (message) {
          _showError(message, isSuccess: true);
          setState(() {
            _showOtpInput = true;
            _pendingPhone = phoneNumber;
          });
        },
        onError: (error) {
          _showError('Phone sign up failed: $error');
        },
      );
    } catch (e) {
      _showError('Phone sign up failed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _signUp() async {
    if (_isPhoneMode) {
      await _signUpWithPhone();
    } else {
      await _signUpWithEmail();
    }
  }

  String _getPrimaryButtonLabel() {
    if (_isPhoneMode && !_showOtpInput) {
      return AppLocalizations.of(context)!.sendOtp;
    } else if (_isPhoneMode && _showOtpInput) {
      return _isSignUpMode ? AppLocalizations.of(context)!.verifySignUp : AppLocalizations.of(context)!.verifySignIn;
    } else {
      return _isSignUpMode ? AppLocalizations.of(context)!.createAccount : AppLocalizations.of(context)!.signIn;
    }
  }

  VoidCallback? _getPrimaryButtonAction() {
    if (_isPhoneMode && !_showOtpInput) {
      // Send OTP phase
      return _isSignUpMode ? _signUpWithPhone : _sendOtpForSignIn;
    } else if (_isPhoneMode && _showOtpInput) {
      // Verify OTP phase
      return _verifyOtp;
    } else {
      // Email mode
      return _isSignUpMode ? _signUpWithEmail : _signInWithEmail;
    }
  }

  Future<void> _sendOtpForSignIn() async {
    final phoneNumber = _emailController.text.trim();
    
    if (phoneNumber.isEmpty) {
      _showError('Please enter a phone number');
      return;
    }

    if (!RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(phoneNumber)) {
      _showError('Please enter a valid phone number (include country code like +1234567890)');
      return;
    }

    _setLoading(true);
    try {
      await _authService.signInWithPhoneNumber(
        phoneNumber,
        onSuccess: (message) {
          _showError(message, isSuccess: true);
          setState(() {
            _showOtpInput = true;
            _pendingPhone = phoneNumber;
          });
        },
        onError: (error) {
          _showError('Failed to send OTP: $error');
        },
      );
    } catch (e) {
      _showError('Failed to send OTP: ${e.toString()}');
    } finally {
      _setLoading(false);
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
    
    // Cancel any existing timeout
    _googleSignInTimeout?.cancel();
    
    // Set up shorter timeout since OAuth often completes but web view gets stuck
    _googleSignInTimeout = Timer(Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _errorMessage = null; // Don't show error - likely succeeded but web view stuck
        });
        // Show a helpful message instead
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign-in may have completed. If you\'re not logged in, please try again.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
    
    try {
      final result = await _authService.signInWithGoogle();
      // For OAuth web flow, result is null by design - auth comes via onAuthStateChange
      if (result != null && result.user != null) {
        // This path is for direct authentication (not used in OAuth web flow)
        print('Google Sign In successful: ${result.user?.email}');
        _googleSignInTimeout?.cancel();
        _setLoading(false);
      } else {
        // OAuth web flow initiated successfully - wait for auth state change
        print('Google OAuth flow initiated - waiting for callback...');
        // Don't show error or stop loading - let auth state listener handle navigation
        // Timeout will handle stuck states
      }
    } catch (e) {
      _googleSignInTimeout?.cancel();
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
    if (_passwordController.text.trim().isEmpty) {
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
        _passwordController.text.trim(),
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
      _passwordController.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VietnameseTiledBackground(
        child: Stack(
          children: [
            // Main login content
            SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            const SizedBox(height: 20),
                  Center(
                    child: Image.asset(
                      'assets/images/text/xo so may manv2.png',
                      height: 100,
                      errorBuilder: (_, __, ___) => const Text(
                        'XỔ SỐ MAY MẮN',
                        style: TextStyle(color: Color(0xFFFFD966), fontSize: 42, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              const SizedBox(height: 20),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFA6A6)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFD966), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 10, offset: const Offset(0,4)),
                  ],
                ),
                child: Column(
                  children: [
                    _buildInputField(
                      controller: _emailController,
                      icon: _isPhoneMode ? Icons.phone : Icons.email,
                                                hint: _isPhoneMode ? AppLocalizations.of(context)!.phone : AppLocalizations.of(context)!.emailPhone,
                      keyboardType: _isPhoneMode ? TextInputType.phone : TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    
                    // Show OTP field only if we're in phone mode and OTP has been sent
                    if (_isPhoneMode && _showOtpInput) ...[
                      _buildInputField(
                        controller: _passwordController,
                        icon: Icons.sms,
                        hint: AppLocalizations.of(context)!.enterOtp,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _resetPhoneAuth,
                            child: Text(
                              AppLocalizations.of(context)!.back,
                              style: TextStyle(color: Color(0xFFFFD966)),
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : () {
                              // Resend OTP
                              _isSignUpMode ? _signUpWithPhone() : _sendOtpForSignIn();
                            },
                            child: Text(
                              AppLocalizations.of(context)!.resendOtp,
                              style: TextStyle(color: Color(0xFFFFD966)),
                            ),
                          ),
                        ],
                      ),
                    ] else if (!_isPhoneMode) ...[
                      _buildInputField(
                        controller: _passwordController,
                        icon: Icons.lock,
                                                    hint: AppLocalizations.of(context)!.password,
                        isPassword: true,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PasswordRecoveryScreen()),
                          );
                        },
                        child: Text(
                          AppLocalizations.of(context)!.forgotPassword,
                          style: const TextStyle(color: Color(0xFFFFD966)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPrimaryButton(
                      label: _getPrimaryButtonLabel(),
                      loading: _isLoading,
                      onPressed: _isLoading ? null : _getPrimaryButtonAction(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              
              // Sign Up / Sign In toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                                        Text(
                        _isSignUpMode ? AppLocalizations.of(context)!.alreadyHaveAccount : AppLocalizations.of(context)!.dontHaveAccount,
                        style: const TextStyle(color: Colors.white70),
                      ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUpMode = !_isSignUpMode;
                        _errorMessage = null;
                      });
                    },
                    child:                       Text(
                        _isSignUpMode ? AppLocalizations.of(context)!.signIn : AppLocalizations.of(context)!.signUp,
                      style: const TextStyle(
                        color: Color(0xFFFFD966),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _buildOrDivider(AppLocalizations.of(context)!.orContinueWith),
              const SizedBox(height: 16),

              _buildAppleButton(_isLoading ? null : _signInWithApple),
              const SizedBox(height: 12),
              _buildGoogleButton(_isLoading ? null : _signInWithGoogle, _isLoading),

              const SizedBox(height: 24),
            ],
          ),
        ),
            ),
            // Floating language switcher in upper right corner
            Positioned(
              top: MediaQuery.of(context).padding.top + 10, // Account for status bar
              right: 16,
              child: Consumer<LanguageService>(
                builder: (context, languageService, child) {
                  final isVietnamese = languageService.currentLocale.languageCode == 'vi';
                  return GestureDetector(
                    onTap: () {
                      languageService.toggleLanguage();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Color(0xFFFFD966).withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isVietnamese ? '🇻🇳' : '🇺🇸',
                            style: TextStyle(fontSize: 18),
                          ),
                          SizedBox(width: 4),
                          Text(
                            isVietnamese ? 'VI' : 'EN',
                            style: TextStyle(
                              color: Color(0xFFFFD966),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword ? _obscurePassword : false,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFFFFD966)),
        hintText: hint,
        hintStyle: TextStyle(color: const Color(0xFFFFD966).withOpacity(0.7)),
        filled: true,
        fillColor: Colors.transparent,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD966), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD966), width: 2),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, color: const Color(0xFFFFD966)),
                onPressed: () { setState(() { _obscurePassword = !_obscurePassword; }); },
              )
            : null,
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildPrimaryButton({required String label, required VoidCallback? onPressed, bool loading = false}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFB30000), Color(0xFF8D0F14)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: const Color(0xFFFFD966).withOpacity(0.3), blurRadius: 8, offset: const Offset(0,4))],
          border: Border.all(color: const Color(0xFFFFD966), width: 1.2),
        ),
        child: Center(
          child: loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD966)))
              : Text(label, style: const TextStyle(color: Color(0xFFFFD966), fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildOrDivider(String text) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0xFFFFD966).withOpacity(0.4))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text, style: const TextStyle(color: Color(0xFFFFD966))),
        ),
        Expanded(child: Container(height: 1, color: const Color(0xFFFFD966).withOpacity(0.4))),
      ],
    );
  }

  Widget _buildAppleButton(VoidCallback? onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.apple, size: 24, color: Colors.white),
      label: Text(AppLocalizations.of(context)!.continueWithApple),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: Color(0xFFFFD966), width: 1),
      ),
    );
  }

  Widget _buildGoogleButton(VoidCallback? onPressed, bool loading) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF5F5F5),
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: Color(0xFFFFD966), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: Color(0xFF4285F4), shape: BoxShape.circle),
            child: const Center(child: Text('G', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 10),
          Text(loading ? AppLocalizations.of(context)!.signingIn : AppLocalizations.of(context)!.continueWithGoogle, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}