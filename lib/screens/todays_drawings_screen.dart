import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../widgets/vietnamese_tiled_background.dart';

class TodaysDrawingsScreen extends StatelessWidget {
  const TodaysDrawingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.todaysDrawings),
      ),
      body: VietnameseTiledBackground(
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
      ),
    );
  }
}
