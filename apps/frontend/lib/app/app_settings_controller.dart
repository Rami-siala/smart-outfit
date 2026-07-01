import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsController extends ChangeNotifier {
  static const String _languageKey = 'selected_language_code';
  static const String _legacyLanguageKey = 'app_language_code';

  Locale _locale = const Locale('en');
  bool _isReady = false;

  Locale get locale => _locale;
  bool get isReady => _isReady;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedLanguage =
        prefs.getString(_languageKey) ?? prefs.getString(_legacyLanguageKey);

    _locale = Locale(storedLanguage ?? 'en');
    _isReady = true;
    notifyListeners();
  }

  // Global locale persistence for the full app.
  Future<void> setLanguage(String languageCode) async {
    _locale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
    await prefs.setString(_legacyLanguageKey, languageCode);
    notifyListeners();
  }
}
