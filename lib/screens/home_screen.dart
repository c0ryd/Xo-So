import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../widgets/vietnamese_tiled_background.dart';
import '../services/supabase_auth_service.dart';
import '../services/language_service.dart';
import '../services/image_storage_service.dart';
import '../utils/responsive_text.dart';
import 'camera_screen_clean.dart'; // Import the clean camera screen
import 'manual_ticket_entry_screen.dart'; // Import manual entry screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _isDrawerOpen = false;
  
  // Shimmer effect variables
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  Timer? _shimmerTimer;
  bool _hasBeenTapped = false;

  @override
  void initState() {
    super.initState();
    _initializeShimmer();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _shimmerTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeShimmer() async {
    // Set up the shimmer animation
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    // Check if the coin has been tapped before
    final prefs = await SharedPreferences.getInstance();
    _hasBeenTapped = prefs.getBool('coin_has_been_tapped') ?? false;

    // Only start shimmer if it hasn't been tapped
    if (!_hasBeenTapped) {
      _startShimmerTimer();
    }
  }

  void _startShimmerTimer() {
    // Start shimmer immediately, then repeat every 3 seconds
    _shimmerController.forward().then((_) {
      _shimmerController.reset();
    });
    
    _shimmerTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_hasBeenTapped && mounted) {
        _shimmerController.forward().then((_) {
          _shimmerController.reset();
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _onCoinTapped() async {
    // Mark as tapped and save to preferences
    setState(() {
      _hasBeenTapped = true;
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('coin_has_been_tapped', true);
    
    // Cancel shimmer timer
    _shimmerTimer?.cancel();
    
    // Check if manual mode is enabled (dev only)
    final isManualMode = await _getManualModeEnabled();
    
    if (isManualMode && kDebugMode) {
      // Navigate to manual entry screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ManualTicketEntryScreen()),
      );
    } else {
      // Navigate to camera screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CameraScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Let content go under AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Transparent AppBar
        elevation: 0, // No shadow
        title: const Text(''), // Empty title
        iconTheme: IconThemeData(color: Color(0xFFFFD966)), // Gold hamburger menu
        automaticallyImplyLeading: !_isDrawerOpen, // Hide hamburger when drawer is open
      ),
      drawer: _buildDrawer(context),
      onDrawerChanged: (isOpened) {
        setState(() {
          _isDrawerOpen = isOpened;
        });
      },
      body: VietnameseTiledBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Only show logo and button when drawer is closed
              if (!_isDrawerOpen) ...[
                // Responsive layout using Column and Flexible instead of fixed positioning
                Column(
                  children: [
                    // Top spacing that adapts to screen size
                    Flexible(
                      flex: 1,
                      child: Container(),
                    ),
                    // Logo image with responsive sizing
                    Flexible(
                      flex: 3,
                      child: Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Responsive logo sizing based on available space
                            final maxHeight = constraints.maxHeight * 0.8;
                            final maxWidth = MediaQuery.of(context).size.width * 0.8;
                            return ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: maxHeight,
                                maxWidth: maxWidth,
                              ),
                              child: Image.asset(
                                'assets/images/text/xo so may manv2.png',
                                fit: BoxFit.contain,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Spacing between logo and button
                    Flexible(
                      flex: 1,
                      child: Container(),
                    ),
                    // Button with responsive sizing
                    Flexible(
                      flex: 4,
                      child: Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Responsive button sizing - made larger
                            final screenWidth = MediaQuery.of(context).size.width;
                            final buttonSize = screenWidth * 0.75; // 75% of screen width (increased from 60%)
                            final maxButtonSize = 350.0; // Maximum size cap (increased from 300px)
                            final finalSize = buttonSize > maxButtonSize ? maxButtonSize : buttonSize;
                            
                            return SizedBox(
                              width: finalSize,
                              height: finalSize,
                child: GestureDetector(
                  onTap: _onCoinTapped,
                  onLongPress: () async {
                    // Debug: Reset shimmer (long press to re-enable shimmer)
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('coin_has_been_tapped', false);
                    setState(() {
                      _hasBeenTapped = false;
                    });
                    _startShimmerTimer();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Shimmer effect reset!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // The coin image
                      Image.asset(
                        'assets/images/button/appButton.png',
                        fit: BoxFit.contain,
                      ),
                      // Shimmer overlay (only show if not tapped yet)
                      if (!_hasBeenTapped)
                        AnimatedBuilder(
                          animation: _shimmerAnimation,
                          builder: (context, child) {
                            return ClipRRect(
                              child: ShaderMask(
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: const [
                                      Colors.transparent,
                                      Color(0xFFFFD966), // Gold shimmer
                                      Colors.transparent,
                                    ],
                                    stops: [
                                      _shimmerAnimation.value - 0.3,
                                      _shimmerAnimation.value,
                                      _shimmerAnimation.value + 0.3,
                                    ],
                                  ).createShader(bounds);
                                },
                                blendMode: BlendMode.srcATop,
                                child: Image.asset(
                                  'assets/images/button/appButton.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Bottom spacing that adapts to screen size
                    Flexible(
                      flex: 2,
                      child: Container(),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.red.withOpacity(0.1), // Transparent red like login screen
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06), // Same as login cards
              border: Border.all(color: Color(0xFFFFD966), width: 1.5), // Gold border
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(height: 20), // Move image up from center
                Image.asset(
                  'assets/images/text/xo so may manv2.png',
                  height: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(
                    'XỔ SỐ MAY MẮN',
                    style: TextStyle(
                      color: Color(0xFFFFD966),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFFFD966).withOpacity(0.3)),
            ),
            child: ListTile(
              leading: Icon(Icons.assessment, color: Color(0xFFFFD966)),
              title: Text(
                AppLocalizations.of(context)!.todaysDrawings,
                style: TextStyle(color: Color(0xFFFFD966)), // Gold text
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/results');
              },
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFFFD966).withOpacity(0.3)),
            ),
            child: ListTile(
              leading: Icon(Icons.confirmation_number, color: Color(0xFFFFD966)),
                              title: Text(
                  AppLocalizations.of(context)!.myTickets,
                  style: ResponsiveText.bodyLarge(context, color: Color(0xFFFFD966)), // Gold text with responsive sizing
                ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/my-tickets');
              },
            ),
          ),

          // Manual mode toggle (dev only)
          if (kDebugMode)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFFFD966).withOpacity(0.3)),
              ),
              child: FutureBuilder<bool>(
                future: _getManualModeEnabled(),
                builder: (context, snapshot) {
                  final isEnabled = snapshot.data ?? false;
                  return ListTile(
                    leading: Icon(
                      isEnabled ? Icons.edit : Icons.camera_alt,
                      color: Color(0xFFFFD966),
                    ),
                    title: Text(
                      'Manual Mode',
                      style: TextStyle(color: Color(0xFFFFD966)),
                    ),
                    trailing: Switch(
                      value: isEnabled,
                      onChanged: (value) async {
                        await _setManualModeEnabled(value);
                        setState(() {}); // Rebuild to update the UI
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value ? 'Manual mode enabled' : 'Manual mode disabled',
                              style: TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Color(0xFFA5362D),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      activeColor: Color(0xFFFFD966),
                      activeTrackColor: Color(0xFFFFD966).withOpacity(0.3),
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.grey.withOpacity(0.3),
                    ),
                  );
                },
              ),
            ),

          // Language toggle - simplified for now
          Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFFFD966).withOpacity(0.3)),
            ),
            child: Consumer<LanguageService>(
              builder: (context, languageService, child) {
                final isVietnamese = languageService.currentLocale.languageCode == 'vi';
                return ListTile(
                  leading: Icon(Icons.language, color: Color(0xFFFFD966)),
                  title: Text(
                    'Language / Ngôn ngữ',
                    style: ResponsiveText.bodyLarge(context, color: Color(0xFFFFD966)), // Gold text with responsive sizing
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isVietnamese ? '🇻🇳 VI' : '🇺🇸 EN',
                        style: TextStyle(
                          color: Color(0xFFFFD966),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.swap_horiz,
                        color: Color(0xFFFFD966).withOpacity(0.6),
                        size: 16,
                      ),
                    ],
                  ),
                  onTap: () {
                    languageService.toggleLanguage();
                    // Don't close drawer when switching languages
                  },
                );
              },
            ),
          ),
          // Image Storage setting
          Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFFFD966).withOpacity(0.3)),
            ),
            child: FutureBuilder<bool>(
              future: ImageStorageService.isImageStorageEnabled(),
              builder: (context, snapshot) {
                final isEnabled = snapshot.data ?? true;
                return ListTile(
                  leading: Icon(
                    isEnabled ? Icons.photo_library : Icons.photo_library_outlined,
                    color: Color(0xFFFFD966),
                  ),
                  title: Text(
                    AppLocalizations.of(context)!.saveImagesLocally,
                    style: TextStyle(color: Color(0xFFFFD966)),
                  ),
                  trailing: Switch(
                    value: isEnabled,
                    onChanged: (value) async {
                      await ImageStorageService.setImageStorageEnabled(value);
                      setState(() {}); // Rebuild to update the UI
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value ? AppLocalizations.of(context)!.imageStorageEnabled : AppLocalizations.of(context)!.imageStorageDisabled,
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Color(0xFFA5362D),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    activeColor: Color(0xFFFFD966),
                    activeTrackColor: Color(0xFFFFD966).withOpacity(0.3),
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.grey.withOpacity(0.3),
                  ),
                );
              },
            ),
          ),
          // Logout button
          Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFFFD966).withOpacity(0.3)),
            ),
            child: ListTile(
              leading: Icon(Icons.logout, color: Color(0xFFFFD966)),
              title: Text(
                AppLocalizations.of(context)!.logout,
                style: TextStyle(color: Color(0xFFFFD966)), // Gold text
              ),
              onTap: () {
                Navigator.pop(context);
                SupabaseAuthService().signOut().then((_) {
                  // Successfully logged out
                  print('✅ User logged out successfully');
                }).catchError((error) {
                  print('❌ Logout error: $error');
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _getManualModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('manual_mode_enabled') ?? false;
  }

  Future<void> _setManualModeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('manual_mode_enabled', enabled);
  }
}
