import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../widgets/vietnamese_tiled_background.dart';
import '../services/supabase_auth_service.dart';
import 'camera_screen_clean.dart'; // Import the clean camera screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isDrawerOpen = false;

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
        child: Stack(
          children: [
            // Only show logo and button when drawer is closed
            if (!_isDrawerOpen) ...[
              // Logo image that extends behind the AppBar
              Positioned(
                top: MediaQuery.of(context).size.height * 0.08, // 8% down from top (2% additional)
                left: 0,
                right: 0,
                child: Image.asset(
                  'assets/images/text/xo so may manv2.png',
                  fit: BoxFit.contain,
                ),
              ),
              // Button positioned with spacing for AppBar
              Positioned(
                top: MediaQuery.of(context).size.height * 0.35, // 35% down from top
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    // Navigate to camera screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CameraScreen()),
                    );
                  },
                  child: Image.asset(
                    'assets/images/button/appButton.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ],
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
                'My Tickets', // TODO: Add to localization
                style: TextStyle(color: Color(0xFFFFD966)), // Gold text
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/my-tickets');
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
            child: ListTile(
              leading: Icon(Icons.language, color: Color(0xFFFFD966)),
              title: Text(
                'Language / Ngôn ngữ',
                style: TextStyle(color: Color(0xFFFFD966)), // Gold text
              ),
              trailing: Text('🇺🇸 🇻🇳'),
              onTap: () {
                // TODO: Implement language toggle
                Navigator.pop(context);
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
                'Logout',
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
}
