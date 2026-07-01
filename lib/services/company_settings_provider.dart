import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class CompanySettingsProvider extends ChangeNotifier {
  static final CompanySettingsProvider _instance = CompanySettingsProvider._internal();
  factory CompanySettingsProvider() => _instance;

  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('company_settings');
  
  Map<String, dynamic> _settings = {};
  bool _initialized = false;

  Map<String, dynamic> get settings => _settings;
  bool get initialized => _initialized;

  // Key standard fields with defaults
  String get companyLogo => _settings['companyLogo'] ?? '';
  String get companyName => _settings['companyName'] ?? 'CARRENT';
  String get companyAddress => _settings['companyAddress'] ?? 'Level 15, Menara Shell\nJalan Tun Sambanthan, KL Sentral\n50470 Kuala Lumpur, Malaysia';
  String get companyPhone => _settings['companyPhone'] ?? '+60 3-2274 1234';
  String get companyEmail => _settings['companyEmail'] ?? 'support@carrent.com.my';
  String get companyWebsite => _settings['companyWebsite'] ?? 'www.carrent.com.my';
  String get companyRegistrationNumber => _settings['companyRegistrationNumber'] ?? '202301012345 (123456-X)';
  String get businessHours => _settings['businessHours'] ?? 'Mon - Fri: 9:00 AM - 6:00 PM MYT';
  String get companyDescription => _settings['companyDescription'] ?? 'Leading car rental system providing premium vehicles.';
  
  // Social media handles as a Map
  Map<String, dynamic> get socialMediaLinks {
    final raw = _settings['socialMediaLinks'];
    if (raw is Map) return _convertToMapStringDynamic(raw);
    return {
      'whatsapp': '+60 12-345 6789',
      'facebook': 'https://facebook.com/carrent',
      'instagram': 'https://instagram.com/carrent',
      'twitter': 'https://twitter.com/carrent',
      'linkedin': 'https://linkedin.com/company/carrent',
    };
  }
  
  // Support contact info as a Map
  Map<String, dynamic> get supportContactInfo {
    final raw = _settings['supportContactInfo'];
    if (raw is Map) return _convertToMapStringDynamic(raw);
    return {
      'whatsapp': '+60 12-345 6789',
      'hotline': '+60 3-2274 1234',
      'email': 'support@carrent.com.my',
    };
  }

  // Dynamic field fallback lookup for future scalability
  dynamic getField(String key, {dynamic defaultValue}) {
    return _settings[key] ?? defaultValue;
  }

  CompanySettingsProvider._internal() {
    _initListener();
  }

  /// Recursively converts a Firebase LinkedMap into `Map<String, dynamic>`.
  /// This is required because Firebase Realtime Database returns nested maps as
  /// `LinkedMap<Object?, Object?>` which cannot be directly cast to `Map<String, dynamic>`.
  Map<String, dynamic> _convertToMapStringDynamic(Map input) {
    final result = <String, dynamic>{};
    input.forEach((key, value) {
      final stringKey = key?.toString() ?? '';
      if (value is Map) {
        result[stringKey] = _convertToMapStringDynamic(value);
      } else if (value is List) {
        result[stringKey] = _convertList(value);
      } else {
        result[stringKey] = value;
      }
    });
    return result;
  }

  List<dynamic> _convertList(List input) {
    return input.map((item) {
      if (item is Map) return _convertToMapStringDynamic(item);
      if (item is List) return _convertList(item);
      return item;
    }).toList();
  }

  void _initListener() {
    _db.onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final rawData = event.snapshot.value;
        if (rawData is Map) {
          // Use recursive conversion to handle nested LinkedMap<Object?, Object?>
          _settings = _convertToMapStringDynamic(rawData);
        }
      } else {
        _settings = _getDefaultSettings();
      }
      _initialized = true;
      notifyListeners();
    }, onError: (error) {
      debugPrint('[CompanySettingsProvider] Error listening: $error');
      // If error (permissions/network), seed defaults locally so the app keeps working
      if (!_initialized) {
        _settings = _getDefaultSettings();
        _initialized = true;
        notifyListeners();
      }
    });
  }

  Map<String, dynamic> _getDefaultSettings() {
    return {
      'companyName': 'CARRENT',
      'companyLogo': '',
      'companyAddress': 'Level 15, Menara Shell\nJalan Tun Sambanthan, KL Sentral\n50470 Kuala Lumpur, Malaysia',
      'companyPhone': '+60 3-2274 1234',
      'companyEmail': 'support@carrent.com.my',
      'companyWebsite': 'www.carrent.com.my',
      'companyRegistrationNumber': '202301012345 (123456-X)',
      'businessHours': 'Mon - Fri: 9:00 AM - 6:00 PM MYT',
      'companyDescription': 'Leading car rental system providing premium vehicles.',
      'socialMediaLinks': {
        'whatsapp': '+60 12-345 6789',
        'facebook': 'https://facebook.com/carrent',
        'instagram': 'https://instagram.com/carrent',
        'twitter': 'https://twitter.com/carrent',
        'linkedin': 'https://linkedin.com/company/carrent',
      },
      'supportContactInfo': {
        'whatsapp': '+60 12-345 6789',
        'hotline': '+60 3-2274 1234',
        'email': 'support@carrent.com.my',
      }
    };
  }

  Future<void> updateSettings(Map<String, dynamic> newSettings) async {
    await _db.set(newSettings);
    // Explicitly update cache to keep singleton in sync immediately
    _settings = Map<String, dynamic>.from(newSettings);
    notifyListeners();
  }
}
