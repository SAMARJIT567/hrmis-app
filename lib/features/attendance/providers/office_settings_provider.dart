// ============================================================
// 📁 lib/features/attendance/providers/office_settings_provider.dart
// ============================================================
// Manages office settings state and persistence.
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/office_settings_model.dart';

class OfficeSettingsProvider extends ChangeNotifier {
  OfficeSettings _settings = OfficeSettings.defaultSettings;
  static const String _settingsKey = 'office_settings_key';

  OfficeSettings get settings => _settings;

  OfficeSettingsProvider() {
    loadSettings();
  }

  void updateSettings(OfficeSettings newSettings) {
    _settings = newSettings;
    notifyListeners();
  }

  void updateRadius(double radius) {
    _settings = _settings.copyWith(allowedRadiusMeters: radius);
    notifyListeners();
  }

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      if (settingsJson != null) {
        _settings = OfficeSettings.fromJson(jsonDecode(settingsJson));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, jsonEncode(_settings.toJson()));
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  // ─── HARDCODED TEST COORDINATES ──────────────────────────────
  // You can change these coordinates to test geofencing easily!
  static const double targetLatitude = 26.2486526; 
  static const double targetLongitude = 91.5086447; 
  static const double targetRadius = 200.0;     // Radius in meters

  Future<void> fetchOfficeSettings() async {
    // Always use these hardcoded coordinates for both Admin and Employee
    _settings = _settings.copyWith(
      officeName: 'GMDA Office',
      latitude: targetLatitude,
      longitude: targetLongitude,
      allowedRadiusMeters: targetRadius,
      id: 'hardcoded_test_id',
    );
    notifyListeners();
    await saveSettings();
  }
}
