import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class LanguageProvider extends ChangeNotifier {
  static final LanguageProvider _instance = LanguageProvider._internal();
  factory LanguageProvider() => _instance;

  static const String _prefsKey = 'selected_language';
  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  LanguageProvider._internal() {
    _init();
  }

  void _init() {
    _loadSavedLanguage();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        syncFromFirebaseUser(user.uid);
      }
    });
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      String? savedCode;
      
      if (user != null) {
        savedCode = prefs.getString('${_prefsKey}_${user.uid}');
      }
      savedCode ??= prefs.getString(_prefsKey);

      if (savedCode != null && (savedCode == 'en' || savedCode == 'ar')) {
        if (_locale.languageCode != savedCode) {
          _locale = Locale(savedCode);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[LanguageProvider] Error loading saved language: $e');
    }
  }

  Future<void> syncFromFirebaseUser(String uid) async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(uid)
          .child('preferredLanguage')
          .get()
          .timeout(const Duration(seconds: 4));

      if (snap.exists && snap.value != null) {
        final lang = snap.value.toString().trim().toLowerCase();
        if ((lang == 'en' || lang == 'ar') && _locale.languageCode != lang) {
          _locale = Locale(lang);
          notifyListeners();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefsKey, lang);
          await prefs.setString('${_prefsKey}_$uid', lang);
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        final localSaved = prefs.getString('${_prefsKey}_$uid') ?? prefs.getString(_prefsKey);
        if (localSaved != null && (localSaved == 'en' || localSaved == 'ar')) {
          if (_locale.languageCode != localSaved) {
            _locale = Locale(localSaved);
            notifyListeners();
          }
          await FirebaseDatabase.instance
              .ref()
              .child('users')
              .child(uid)
              .child('preferredLanguage')
              .set(localSaved);
        }
      }
    } catch (e) {
      debugPrint('[LanguageProvider] Error syncing user language from DB: $e');
    }
  }

  Future<void> syncUserLanguage(String langCode) async {
    final lang = langCode.trim().toLowerCase();
    if ((lang == 'en' || lang == 'ar') && _locale.languageCode != lang) {
      _locale = Locale(lang);
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, lang);
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await prefs.setString('${_prefsKey}_${user.uid}', lang);
        }
      } catch (e) {
        debugPrint('[LanguageProvider] Error saving local sync language: $e');
      }
    }
  }

  Future<void> setLocale(Locale newLocale) async {
    if (_locale == newLocale) return;
    _locale = newLocale;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final langCode = newLocale.languageCode;
      await prefs.setString(_prefsKey, langCode);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await prefs.setString('${_prefsKey}_${user.uid}', langCode);
        await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(user.uid)
            .child('preferredLanguage')
            .set(langCode)
            .timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('[LanguageProvider] Error saving language: $e');
    }
  }

  Future<void> toggleLanguage() async {
    final nextLocale = isArabic ? const Locale('en') : const Locale('ar');
    await setLocale(nextLocale);
  }
}
