import 'package:flutter/material.dart';

class VietnameseTiledBackground extends StatelessWidget {
  final Widget? child;
  final String imagePath;
  final double originalTileSize;
  final bool enableStaticScrolling;

  const VietnameseTiledBackground({
    Key? key,
    this.child,
    this.imagePath = 'assets/images/backgrounds/vietnamese_tile_dark.png',
    this.originalTileSize = 200.0,
    this.enableStaticScrolling = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate tile size to fit exactly 4 tiles across the screen width
        double tileSize = constraints.maxWidth / 4;
        
        // Calculate how many rows we need to fill the screen height
        int rowsNeeded = (constraints.maxHeight / tileSize).ceil();
        
        // Calculate scale factor to resize the original tile
        double scale = tileSize > 0 ? (originalTileSize / tileSize) : 1.0;
        
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(imagePath),
              repeat: ImageRepeat.repeat,
              fit: BoxFit.none,
              scale: scale,
            ),
          ),
          child: child,
        );
      },
    );
  }
}

/// A wrapper that provides static background scrolling behavior
class StaticTiledBackground extends StatelessWidget {
  final Widget child;
  final String imagePath;
  final double originalTileSize;

  const StaticTiledBackground({
    Key? key,
    required this.child,
    this.imagePath = 'assets/images/backgrounds/vietnamese_tile_dark.png',
    this.originalTileSize = 200.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Static background layer
        Positioned.fill(
          child: VietnameseTiledBackground(
            imagePath: imagePath,
            originalTileSize: originalTileSize,
          ),
        ),
        // Scrollable content layer
        child,
      ],
    );
  }
}

