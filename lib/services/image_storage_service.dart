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
  /// Uses ApplicationSupportDirectory for better persistence across app updates
  static Future<Directory> _getTicketImagesDirectory() async {
    Directory appDir;
    try {
      // Try to use ApplicationSupportDirectory for better persistence
      appDir = await getApplicationSupportDirectory();
    } catch (e) {
      // Fallback to ApplicationDocumentsDirectory if support directory unavailable
      print('⚠️ ApplicationSupportDirectory unavailable, using Documents: $e');
      appDir = await getApplicationDocumentsDirectory();
    }
    
    final ticketImagesDir = Directory('${appDir.path}/$_ticketImagesDir');
    
    if (!await ticketImagesDir.exists()) {
      await ticketImagesDir.create(recursive: true);
    }
    
    return ticketImagesDir;
  }

  /// Save processed ticket image locally
  /// Returns the relative file name if successful, null if storage is disabled or failed
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
      
      // Return relative filename instead of absolute path for database storage
      return fileName;
    } catch (e) {
      print('❌ Error saving ticket image: $e');
      return null;
    }
  }

  /// Get ticket image file if it exists
  /// Handles both relative filenames (new format) and absolute paths (legacy format)
  static Future<File?> getTicketImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) {
      return null;
    }

    try {
      File? file;
      
      // Check if this is a relative filename (new format) or absolute path (legacy)
      if (imagePath.startsWith('/')) {
        // Legacy absolute path - check if migration is needed
        final migratedPath = await getMigratedImagePath(imagePath);
        if (migratedPath != null) {
          file = File(migratedPath);
        }
      } else {
        // New relative filename format - construct full path
        final imagesDir = await _getTicketImagesDirectory();
        final fullPath = '${imagesDir.path}/$imagePath';
        file = File(fullPath);
      }
      
      if (file != null && await file.exists()) {
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
  /// Handles both relative filenames (new format) and absolute paths (legacy format)
  static Future<bool> deleteTicketImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) {
      return true; // Nothing to delete
    }

    try {
      File? file;
      
      // Check if this is a relative filename (new format) or absolute path (legacy)
      if (imagePath.startsWith('/')) {
        // Legacy absolute path - check if migration is needed
        final migratedPath = await getMigratedImagePath(imagePath);
        if (migratedPath != null) {
          file = File(migratedPath);
        }
      } else {
        // New relative filename format - construct full path
        final imagesDir = await _getTicketImagesDirectory();
        final fullPath = '${imagesDir.path}/$imagePath';
        file = File(fullPath);
      }
      
      if (file != null && await file.exists()) {
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

  /// Migrate existing images from Documents to Support directory
  static Future<void> _migrateImagesToSupportDirectory() async {
    try {
      // Check if we can get both directories
      final oldDir = await getApplicationDocumentsDirectory();
      final newDir = await getApplicationSupportDirectory();
      
      final oldImagesDir = Directory('${oldDir.path}/$_ticketImagesDir');
      final newImagesDir = Directory('${newDir.path}/$_ticketImagesDir');
      
      // If old directory exists and has files, migrate them
      if (await oldImagesDir.exists()) {
        final files = await oldImagesDir.list().where((entity) => 
            entity is File && entity.path.endsWith('.jpg')).toList();
        
        if (files.isNotEmpty) {
          print('🔄 Migrating ${files.length} images from Documents to Support directory...');
          
          // Ensure new directory exists
          if (!await newImagesDir.exists()) {
            await newImagesDir.create(recursive: true);
          }
          
          int migratedCount = 0;
          for (final file in files) {
            try {
              final fileName = file.path.split('/').last;
              final newFilePath = '${newImagesDir.path}/$fileName';
              
              // Only copy if the file doesn't already exist in the new location
              if (!await File(newFilePath).exists()) {
                await File(file.path).copy(newFilePath);
                await File(file.path).delete(); // Remove from old location
                migratedCount++;
              }
            } catch (e) {
              print('⚠️ Failed to migrate file ${file.path}: $e');
            }
          }
          
          print('✅ Successfully migrated $migratedCount images to Support directory');
          
          // Try to remove old directory if it's empty
          try {
            final remainingFiles = await oldImagesDir.list().toList();
            if (remainingFiles.isEmpty) {
              await oldImagesDir.delete();
              print('✅ Removed empty old images directory');
            }
          } catch (e) {
            print('⚠️ Could not remove old directory: $e');
          }
        }
      }
    } catch (e) {
      print('⚠️ Error during image migration: $e');
    }
  }

  /// Check if an image path needs to be migrated (is in old Documents location)
  static Future<String?> getMigratedImagePath(String? originalPath) async {
    if (originalPath == null || originalPath.isEmpty) {
      return originalPath;
    }
    
    try {
      // Check if this is an old Documents directory path
      final documentsDir = await getApplicationDocumentsDirectory();
      final supportDir = await getApplicationSupportDirectory();
      
      final oldBasePath = '${documentsDir.path}/$_ticketImagesDir';
      final newBasePath = '${supportDir.path}/$_ticketImagesDir';
      
      // If the path points to the old location, update it to the new location
      if (originalPath.startsWith(oldBasePath)) {
        final relativePath = originalPath.substring(oldBasePath.length);
        final newPath = '$newBasePath$relativePath';
        
        // Check if the file exists in the new location
        if (await File(newPath).exists()) {
          return newPath;
        }
      }
      
      // If the file exists at the original path, return it unchanged
      if (await File(originalPath).exists()) {
        return originalPath;
      }
      
      // File doesn't exist in either location
      return null;
    } catch (e) {
      print('⚠️ Error checking migrated path for $originalPath: $e');
      return originalPath;
    }
  }

  /// Extract filename from absolute path for database migration
  /// Converts legacy absolute paths to relative filenames
  static String? extractFilenameFromPath(String? absolutePath) {
    if (absolutePath == null || absolutePath.isEmpty) {
      return absolutePath;
    }
    
    // If it's already a relative filename, return as-is
    if (!absolutePath.startsWith('/')) {
      return absolutePath;
    }
    
    // Extract filename from absolute path
    final parts = absolutePath.split('/');
    if (parts.isNotEmpty) {
      final filename = parts.last;
      // Verify it looks like an image filename
      if (filename.endsWith('.jpg') || filename.endsWith('.jpeg') || filename.endsWith('.png')) {
        return filename;
      }
    }
    
    return null;
  }

  /// Remove duplicate images based on ticket number and date
  /// Keeps the newest image for each unique ticket+date combination
  static Future<int> removeDuplicateImages() async {
    try {
      final imagesDir = await _getTicketImagesDirectory();
      if (!await imagesDir.exists()) {
        return 0;
      }

      // Get all image files
      final imageFiles = <File>[];
      await for (final entity in imagesDir.list()) {
        if (entity is File && entity.path.endsWith('.jpg')) {
          imageFiles.add(entity);
        }
      }

      if (imageFiles.isEmpty) {
        return 0;
      }

      print('🔍 Checking ${imageFiles.length} images for duplicates...');

      // Group files by ticket number and date (extracted from filename)
      final Map<String, List<File>> groupedFiles = {};
      
      for (final file in imageFiles) {
        final filename = file.path.split('/').last;
        
        // Parse filename format: ticket_[ticketNumber]_[timestamp]_[timestamp2].jpg
        final match = RegExp(r'ticket_(\d+)_(\d+)_\d+\.jpg').firstMatch(filename);
        if (match != null) {
          final ticketNumber = match.group(1)!;
          final timestamp = int.tryParse(match.group(2)!) ?? 0;
          
          // Convert timestamp to date (YYYY-MM-DD) for grouping
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          
          final key = '${ticketNumber}_$dateKey';
          
          if (!groupedFiles.containsKey(key)) {
            groupedFiles[key] = [];
          }
          groupedFiles[key]!.add(file);
        }
      }

      int deletedCount = 0;
      
      // For each group, keep only the newest file (by modification time)
      for (final entry in groupedFiles.entries) {
        final files = entry.value;
        if (files.length > 1) {
          // Sort by modification time (newest first)
          files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
          
          // Delete all but the first (newest) file
          for (int i = 1; i < files.length; i++) {
            try {
              await files[i].delete();
              deletedCount++;
              print('🗑️ Deleted duplicate image: ${files[i].path.split('/').last}');
            } catch (e) {
              print('⚠️ Failed to delete duplicate ${files[i].path}: $e');
            }
          }
        }
      }

      if (deletedCount > 0) {
        print('✅ Removed $deletedCount duplicate images');
      } else {
        print('✅ No duplicate images found');
      }
      
      return deletedCount;
    } catch (e) {
      print('❌ Error removing duplicate images: $e');
      return 0;
    }
  }

  /// Initialize image storage service
  static Future<void> initialize() async {
    try {
      // First, migrate any existing images from Documents to Support directory
      await _migrateImagesToSupportDirectory();
      
      // Ensure images directory exists
      await _getTicketImagesDirectory();
      
      // Run cleanup on startup (remove images older than 30 days and duplicates)
      await cleanupOldImages(daysOld: 30);
      await removeDuplicateImages();
      
      print('✅ ImageStorageService initialized');
    } catch (e) {
      print('❌ Error initializing ImageStorageService: $e');
    }
  }
}
