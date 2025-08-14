import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../widgets/vietnamese_tiled_background.dart';
import 'camera_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appTitle),
      ),
      drawer: _buildDrawer(context),
      body: VietnameseTiledBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Scan button - updated with camera icon as requested
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CameraScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFE8BE),
                  foregroundColor: Colors.black87,
                  padding: EdgeInsets.all(24), // Square padding
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16), // Rounded corners
                  ),
                  minimumSize: Size(80, 80), // Make it more square
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: 32,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Tap to scan a lottery ticket',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
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
        ],
      ),
    );
  }
}
