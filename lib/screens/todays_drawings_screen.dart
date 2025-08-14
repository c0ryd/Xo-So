import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TodaysDrawingsScreen extends StatelessWidget {
  const TodaysDrawingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.todaysDrawings,
          style: const TextStyle(
            color: Color(0xFFFFE8BE), // Light cream text color
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF91000C), // Darker red color
        foregroundColor: const Color(0xFFFFE8BE), // Light cream text
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent, // Make status bar transparent
          statusBarIconBrightness: Brightness.light, // Light icons (cream color)
          statusBarBrightness: Brightness.dark, // For iOS
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate tile size to fit exactly 4 tiles across the screen width
          double tileSize = constraints.maxWidth / 4;
          
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
                                   image: DecorationImage(
                       image: const AssetImage('assets/images/backgrounds/vietnamese_tile_dark.png'),
                       repeat: ImageRepeat.repeat,
                       fit: BoxFit.none,
                       scale: tileSize > 0 ? (200 / tileSize) : 1.0, // Assuming original tile is ~200px
                     ),
            ),
            // Empty container for now - just showing the background
            child: const Center(
              child: Text(
                'Today\'s Drawings',
                style: TextStyle(
                  color: Color(0xFFFFE8BE), // Light cream text color
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 3,
                      color: Colors.black45,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
