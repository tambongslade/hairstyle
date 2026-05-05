import 'package:flutter/material.dart';
import 'translations.dart';

class AppLocale extends ChangeNotifier {
  static final AppLocale _instance = AppLocale._();
  static AppLocale get instance => _instance;

  AppLocale._();

  String _languageCode = 'en';
  String get languageCode => _languageCode;
  bool get isEnglish => _languageCode == 'en';
  bool get isFrench => _languageCode == 'fr';

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;

  void setLanguage(String code) {
    if (code != _languageCode) {
      _languageCode = code;
      notifyListeners();
    }
  }

  void toggleLanguage() {
    setLanguage(_languageCode == 'en' ? 'fr' : 'en');
  }

  void setThemeMode(ThemeMode mode) {
    if (mode != _themeMode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  void toggleTheme() {
    setThemeMode(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  String tr(String key) {
    return Translations.get(key, _languageCode);
  }
}

/// Shortcut to translate a key using the current locale
String tr(String key) => AppLocale.instance.tr(key);
