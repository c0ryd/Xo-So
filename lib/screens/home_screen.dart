import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../widgets/vietnamese_tiled_background.dart';
import '../services/supabase_auth_service.dart';
import 'camera_screen_clean.dart'; // Import the clean camera screen

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Let content go under AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Transparent AppBar
        elevation: 0, // No shadow
        title: const Text(''), // Empty title
      ),
      drawer: _buildDrawer(context),
      body: VietnameseTiledBackground(
        child: Stack(
          children: [
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
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Color(0xFFFFE8BE), // Cream background
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF91000C),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  AppLocalizations.of(context)!.appTitle,
                  style: TextStyle(
                    color: Color(0xFFFFE8BE),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Vietnam Lottery Scanner',
                  style: TextStyle(
                    color: Color(0xFFFFE8BE).withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.assessment, color: Colors.black87),
            title: Text(
              AppLocalizations.of(context)!.todaysDrawings,
              style: TextStyle(color: Colors.black87),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/results');
            },
          ),
          ListTile(
            leading: Icon(Icons.confirmation_number, color: Colors.black87),
            title: Text(
              'My Tickets', // TODO: Add to localization
              style: TextStyle(color: Colors.black87),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/my-tickets');
            },
          ),
          // Language toggle - simplified for now
          ListTile(
            leading: Icon(Icons.language, color: Colors.black87),
            title: Text(
              'Language / Ngôn ngữ',
              style: TextStyle(color: Colors.black87),
            ),
            trailing: Text('🇺🇸 🇻🇳'),
            onTap: () {
              // TODO: Implement language toggle
              Navigator.pop(context);
            },
          ),
          // Logout button
          ListTile(
            leading: Icon(Icons.logout, color: Colors.black87),
            title: Text(
              'Logout',
              style: TextStyle(color: Colors.black87),
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
        ],
      ),
    );
  }
}
