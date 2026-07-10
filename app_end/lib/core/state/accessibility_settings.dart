import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilitySettings extends ChangeNotifier {
  static const double minTextScale = 0.85;
  static const double maxTextScale = 1.6;

  static const _keyTextScale = 'a11y_text_scale';
  static const _keyHighContrast = 'a11y_high_contrast';
  static const _keyDyslexiaFriendly = 'a11y_dyslexia_friendly';
  static const _keyAutoSpeak = 'a11y_auto_speak';

  double _textScale = 1.15;
  bool _highContrast = false;
  bool _dyslexiaFriendly = false;
  bool _autoSpeak = true;

  double get textScale => _textScale;
  bool get highContrast => _highContrast;
  bool get dyslexiaFriendly => _dyslexiaFriendly;
  bool get autoSpeak => _autoSpeak;

  /// Back-compat convenience for anything still checking a binary toggle.
  bool get largeText => _textScale > 1.0;

  /// Loads persisted values. Call once at startup before first paint so the
  /// UI doesn't flash defaults before the saved preferences apply.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _textScale = prefs.getDouble(_keyTextScale) ?? _textScale;
    _highContrast = prefs.getBool(_keyHighContrast) ?? _highContrast;
    _dyslexiaFriendly =
        prefs.getBool(_keyDyslexiaFriendly) ?? _dyslexiaFriendly;
    _autoSpeak = prefs.getBool(_keyAutoSpeak) ?? _autoSpeak;
    notifyListeners();
  }

  Future<void> setTextScale(double value) async {
    final clamped = value.clamp(minTextScale, maxTextScale);
    if (_textScale == clamped) return;
    _textScale = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTextScale, clamped);
  }

  Future<void> setHighContrast(bool value) async {
    if (_highContrast == value) return;
    _highContrast = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHighContrast, value);
  }

  Future<void> setDyslexiaFriendly(bool value) async {
    if (_dyslexiaFriendly == value) return;
    _dyslexiaFriendly = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDyslexiaFriendly, value);
  }

  Future<void> setAutoSpeak(bool value) async {
    if (_autoSpeak == value) return;
    _autoSpeak = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoSpeak, value);
  }
}
