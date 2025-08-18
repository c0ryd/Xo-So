import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'dart:math' as math;

/// Simple but effective image preprocessing for OCR
class ImagePreprocessing {
  
  /// Apply simple but effective preprocessing for OCR
  static img.Image enhanceForOCR(img.Image image) {
    print('🔧 Applying simple OCR enhancement...');
    
    // Simple approach: Just improve contrast and sharpness
    final enhanced = img.adjustColor(image, 
      brightness: 1.1,      // Slightly brighter
      contrast: 1.3,        // More contrast
      saturation: 0.9,      // Less saturation (closer to grayscale)
    );
    
    print('🔧 Simple enhancement complete');
    return enhanced;
  }
  
  /// Smart contrast enhancement that preserves details
  static img.Image _enhanceContrast(img.Image image) {
    // Calculate histogram
    final histogram = List<int>.filled(256, 0);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.round();
        final g = pixel.g.round();
        final b = pixel.b.round();
        final gray = ((r + g + b) / 3).round();
        histogram[gray]++;
      }
    }
    
    // Find 1st and 99th percentiles for contrast stretching
    final totalPixels = image.width * image.height;
    int lowCutoff = 0, highCutoff = 255;
    int cumulative = 0;
    
    for (int i = 0; i < 256; i++) {
      cumulative += histogram[i];
      if (cumulative > totalPixels * 0.01 && lowCutoff == 0) {
        lowCutoff = i;
      }
      if (cumulative > totalPixels * 0.99) {
        highCutoff = i;
        break;
      }
    }
    
    // Apply contrast stretching
    final range = highCutoff - lowCutoff;
    if (range > 0) {
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.round();
          final g = pixel.g.round();
          final b = pixel.b.round();
          
          final newR = ((r - lowCutoff) * 255 / range).clamp(0, 255).round();
          final newG = ((g - lowCutoff) * 255 / range).clamp(0, 255).round();
          final newB = ((b - lowCutoff) * 255 / range).clamp(0, 255).round();
          
          image.setPixel(x, y, img.ColorRgb8(newR, newG, newB));
        }
      }
    }
    
    return image;
  }
  
  /// Advanced sharpening using unsharp mask
  static img.Image _sharpenImage(img.Image image) {
    // Create a slightly blurred version
    final blurred = _gaussianBlur(image, radius: 1.0);
    
    // Apply unsharp mask: original + (original - blurred) * strength
    const strength = 1.5;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final originalPixel = image.getPixel(x, y);
        final blurredPixel = blurred.getPixel(x, y);
        
        final r = originalPixel.r.round();
        final g = originalPixel.g.round();
        final b = originalPixel.b.round();
        
        final blurR = blurredPixel.r.round();
        final blurG = blurredPixel.g.round();
        final blurB = blurredPixel.b.round();
        
        final newR = (r + (r - blurR) * strength).clamp(0, 255).round();
        final newG = (g + (g - blurG) * strength).clamp(0, 255).round();
        final newB = (b + (b - blurB) * strength).clamp(0, 255).round();
        
        image.setPixel(x, y, img.ColorRgb8(newR, newG, newB));
      }
    }
    
    return image;
  }
  
  /// Adaptive binarization using Otsu's method
  static img.Image _adaptiveBinarization(img.Image image) {
    // Convert to grayscale first
    final gray = img.grayscale(image);
    
    // Calculate histogram
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final pixel = gray.getPixel(x, y);
        final grayValue = pixel.r.round(); // Since it's grayscale, R=G=B
        histogram[grayValue]++;
      }
    }
    
    // Otsu's method to find optimal threshold
    final totalPixels = gray.width * gray.height;
    double sum = 0;
    for (int i = 0; i < 256; i++) {
      sum += i * histogram[i];
    }
    
    double sumB = 0;
    int wB = 0;
    int wF = 0;
    double varMax = 0;
    int threshold = 0;
    
    for (int t = 0; t < 256; t++) {
      wB += histogram[t];
      if (wB == 0) continue;
      
      wF = totalPixels - wB;
      if (wF == 0) break;
      
      sumB += t * histogram[t];
      
      final mB = sumB / wB;
      final mF = (sum - sumB) / wF;
      
      final varBetween = wB * wF * (mB - mF) * (mB - mF);
      
      if (varBetween > varMax) {
        varMax = varBetween;
        threshold = t;
      }
    }
    
    // Apply threshold
    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final pixel = gray.getPixel(x, y);
        final grayValue = pixel.r.round();
        final newValue = grayValue > threshold ? 255 : 0;
        gray.setPixel(x, y, img.ColorRgb8(newValue, newValue, newValue));
      }
    }
    
    return gray;
  }
  
  /// Gamma correction for brightness adjustment
  static img.Image _adjustGamma(img.Image image, {double gamma = 1.0}) {
    final gammaTable = List<int>.generate(256, (i) => 
        (255 * math.pow(i / 255.0, 1.0 / gamma)).round().clamp(0, 255));
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = gammaTable[pixel.r.round()];
        final g = gammaTable[pixel.g.round()];
        final b = gammaTable[pixel.b.round()];
        image.setPixel(x, y, img.ColorRgb8(r, g, b));
      }
    }
    
    return image;
  }
  
  /// Simple Gaussian blur
  static img.Image _gaussianBlur(img.Image image, {double radius = 1.0}) {
    return img.gaussianBlur(image, radius: radius.round());
  }
  
  /// Detect and correct skew/rotation of text
  static img.Image correctSkew(img.Image image) {
    // This is a simplified skew detection
    // In a production app, you might want to use more sophisticated algorithms
    return image; // For now, return unchanged
  }
  
  /// Enhance image specifically for numbers (lottery tickets)
  static img.Image enhanceForNumbers(img.Image image) {
    print('🔢 Enhancing image for lottery ticket numbers...');
    
    // Simple enhancement that works well for lottery tickets
    final enhanced = img.adjustColor(image, 
      brightness: 1.15,     // Brighter for better number visibility
      contrast: 1.4,        // Higher contrast for sharp text
      saturation: 0.8,      // Reduce color noise
    );
    
    return enhanced;
  }
  
  /// Get optimal camera settings for OCR
  static Map<String, dynamic> getOptimalSettings() {
    return {
      'focusMode': 'auto',
      'exposureMode': 'auto',
      'whiteBalance': 'auto',
      'imageQuality': 95,
      'preferredResolution': 'high', // Balance between quality and processing time
    };
  }
  
  /// Calculate optimal exposure values for multi-shot OCR
  static List<double> getExposureSequence() {
    return [-0.7, 0.0, 0.7]; // Slightly less extreme than current -1.0, 0.0, 1.0
  }
}
