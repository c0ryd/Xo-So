import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

class ImageStorageService {
  static const String _imageStorageEnabledKey = 'image_storage_enabled';
  static const String _ticketImagesDir = 'ticket_images';

  /// Check if image storage is enabled in user settings
  static Future<bool> isImageStorageEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_imageStorageEnabledKey) ?? true; // Default to enabled
  }

  /// Enable or disable image storage
  static Future<void> setImageStorageEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_imageStorageEnabledKey, enabled);
  }

  /// Get the ticket images directory
  static Future<Directory> _getTicketImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final ticketImagesDir = Directory('${appDir.path}/$_ticketImagesDir');
    
    if (!await ticketImagesDir.exists()) {
      await ticketImagesDir.create(recursive: true);
    }
    
    return ticketImagesDir;
  }

  /// Save processed ticket image locally
  /// Returns the local file path if successful, null if storage is disabled or failed
  static Future<String?> saveTicketImage({
    required Uint8List imageBytes,
    required String ticketId,
    int quality = 85,
  }) async {
    try {
      // Check if image storage is enabled
      if (!await isImageStorageEnabled()) {
        print('📸 Image storage disabled, skipping save');
        return null;
      }

      // Get images directory
      final imagesDir = await _getTicketImagesDirectory();
      
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'ticket_${ticketId}_$timestamp.jpg';
      final filePath = '${imagesDir.path}/$fileName';
      
      // Compress and save image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        print('❌ Failed to decode image for ticket $ticketId');
        return null;
      }

      // Compress image to reduce file size
      final compressedBytes = img.encodeJpg(image, quality: quality);
      
      // Save to file
      final file = File(filePath);
      await file.writeAsBytes(compressedBytes);
      
      // Calculate file size for logging
      final fileSizeKB = (await file.length()) / 1024;
      print('✅ Saved ticket image: $fileName (${fileSizeKB.toStringAsFixed(1)} KB)');
      
      return filePath;
    } catch (e) {
      print('❌ Error saving ticket image: $e');
      return null;
    }
  }

  /// Get ticket image file if it exists
  static Future<File?> getTicketImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) {
      return null;
    }

    try {
      final file = File(imagePath);
      if (await file.exists()) {
        return file;
      } else {
        print('⚠️ Ticket image not found: $imagePath');
        return null;
      }
    } catch (e) {
      print('❌ Error loading ticket image: $e');
      return null;
    }
  }

  /// Delete ticket image file
  static Future<bool> deleteTicketImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) {
      return true; // Nothing to delete
    }

    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        print('🗑️ Deleted ticket image: ${file.path}');
        return true;
      }
      return true; // File doesn't exist, consider it deleted
    } catch (e) {
      print('❌ Error deleting ticket image: $e');
      return false;
    }
  }

  /// Clean up images older than the specified number of days
  static Future<int> cleanupOldImages({int daysOld = 30}) async {
    try {
      final imagesDir = await _getTicketImagesDirectory();
      if (!await imagesDir.exists()) {
        return 0;
      }

      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      int deletedCount = 0;

      await for (final entity in imagesDir.list()) {
        if (entity is File && entity.path.endsWith('.jpg')) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            try {
              await entity.delete();
              deletedCount++;
              print('🗑️ Cleaned up old image: ${entity.path}');
            } catch (e) {
              print('❌ Error deleting old image ${entity.path}: $e');
            }
          }
        }
      }

      if (deletedCount > 0) {
        print('✅ Cleaned up $deletedCount old ticket images');
      }

      return deletedCount;
    } catch (e) {
      print('❌ Error during image cleanup: $e');
      return 0;
    }
  }

  /// Get storage usage statistics
  static Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final imagesDir = await _getTicketImagesDirectory();
      if (!await imagesDir.exists()) {
        return {
          'totalFiles': 0,
          'totalSizeKB': 0.0,
          'oldestImage': null,
          'newestImage': null,
        };
      }

      int totalFiles = 0;
      int totalSizeBytes = 0;
      DateTime? oldestDate;
      DateTime? newestDate;

      await for (final entity in imagesDir.list()) {
        if (entity is File && entity.path.endsWith('.jpg')) {
          totalFiles++;
          final stat = await entity.stat();
          totalSizeBytes += stat.size;
          
          if (oldestDate == null || stat.modified.isBefore(oldestDate)) {
            oldestDate = stat.modified;
          }
          if (newestDate == null || stat.modified.isAfter(newestDate)) {
            newestDate = stat.modified;
          }
        }
      }

      return {
        'totalFiles': totalFiles,
        'totalSizeKB': totalSizeBytes / 1024,
        'oldestImage': oldestDate,
        'newestImage': newestDate,
      };
    } catch (e) {
      print('❌ Error getting storage stats: $e');
      return {
        'totalFiles': 0,
        'totalSizeKB': 0.0,
        'oldestImage': null,
        'newestImage': null,
      };
    }
  }

  /// Initialize image storage service
  static Future<void> initialize() async {
    try {
      // Ensure images directory exists
      await _getTicketImagesDirectory();
      
      // Run cleanup on startup (remove images older than 30 days)
      await cleanupOldImages();
      
      print('✅ ImageStorageService initialized');
    } catch (e) {
      print('❌ Error initializing ImageStorageService: $e');
    }
  }
}
