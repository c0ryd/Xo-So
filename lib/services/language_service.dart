import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  
  Locale _currentLocale = const Locale('en'); // Default to English

  Locale get currentLocale => _currentLocale;

  LanguageService() {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey) ?? 'en';
    _currentLocale = Locale(languageCode);
    notifyListeners();
  }

  Future<void> setLanguage(Locale locale) async {
    if (_currentLocale == locale) return;
    
    _currentLocale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, locale.languageCode);
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    final newLocale = _currentLocale.languageCode == 'en' 
        ? const Locale('vi') 
        : const Locale('en');
    await setLanguage(newLocale);
  }

  bool get isEnglish => _currentLocale.languageCode == 'en';
  bool get isVietnamese => _currentLocale.languageCode == 'vi';
}
