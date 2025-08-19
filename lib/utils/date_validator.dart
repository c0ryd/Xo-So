import 'package:intl/intl.dart';

class DateValidator {
  /// Validates if a date string represents a valid lottery date within the acceptable range
  /// Min: Today - 60 days
  /// Max: Today + 2 days
  static bool isValidLotteryDate(String dateString) {
    final parsedDate = _parseDate(dateString);
    if (parsedDate == null) return false;
    
    final now = DateTime.now();
    final minDate = now.subtract(const Duration(days: 60));
    final maxDate = now.add(const Duration(days: 2));
    
    // Check if date is within the valid range
    final isInRange = parsedDate.isAfter(minDate.subtract(const Duration(days: 1))) && 
                     parsedDate.isBefore(maxDate.add(const Duration(days: 1)));
    
    if (!isInRange) {
      print('📅 Date validation failed: $dateString (parsed: ${_formatDate(parsedDate)})');
      print('📅 Valid range: ${_formatDate(minDate)} to ${_formatDate(maxDate)}');
    }
    
    return isInRange;
  }
  
  /// Parse various date formats commonly found on Vietnamese lottery tickets
  static DateTime? _parseDate(String dateString) {
    if (dateString == 'Not found' || dateString.isEmpty) return null;
    
    // Clean the date string
    final cleaned = dateString.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    // Try different date formats
    final formats = [
      'dd-MM-yyyy',   // 15-08-2024
      'dd/MM/yyyy',   // 15/08/2024
      'dd.MM.yyyy',   // 15.08.2024
      'dd MM yyyy',   // 15 08 2024
      'yyyy-MM-dd',   // 2024-08-15
      'yyyy/MM/dd',   // 2024/08/15
      'dd-MM-yy',     // 15-08-24 (2-digit year)
      'dd/MM/yy',     // 15/08/24 (2-digit year)
    ];
    
    for (final formatStr in formats) {
      try {
        final formatter = DateFormat(formatStr);
        final parsed = formatter.parseStrict(cleaned);
        
        // Handle 2-digit years (assume 20xx if year < 50, 19xx if >= 50)
        if (formatStr.contains('yy') && !formatStr.contains('yyyy')) {
          final year = parsed.year;
          if (year < 1950) {
            // Adjust 2-digit year to 4-digit
            final adjustedYear = year < 50 ? 2000 + year : 1900 + year;
            return DateTime(adjustedYear, parsed.month, parsed.day);
          }
        }
        
        return parsed;
      } catch (e) {
        // Try next format
        continue;
      }
    }
    
    print('⚠️ Could not parse date: "$dateString"');
    return null;
  }
  
  /// Format date for logging
  static String _formatDate(DateTime date) {
    return DateFormat('dd-MM-yyyy').format(date);
  }
  
  /// Get the valid date range for display/debugging
  static String getValidDateRange() {
    final now = DateTime.now();
    final minDate = now.subtract(const Duration(days: 60));
    final maxDate = now.add(const Duration(days: 2));
    
    return '${_formatDate(minDate)} to ${_formatDate(maxDate)}';
  }
  
  /// Check if a date is too old (older than 60 days)
  static bool isTooOld(String dateString) {
    final parsedDate = _parseDate(dateString);
    if (parsedDate == null) return false;
    
    final now = DateTime.now();
    final minDate = now.subtract(const Duration(days: 60));
    
    return parsedDate.isBefore(minDate);
  }
  
  /// Check if a date is too far in the future (more than 2 days)
  static bool isTooFuture(String dateString) {
    final parsedDate = _parseDate(dateString);
    if (parsedDate == null) return false;
    
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 2));
    
    return parsedDate.isAfter(maxDate);
  }
}
