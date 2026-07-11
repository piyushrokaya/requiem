import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilitySettings extends ChangeNotifier {
  static const double minTextScale = 0.85;
  // Low-vision users often need much larger text, so the ceiling goes to 200%.
  static const double maxTextScale = 2.0;

  // Quick presets exposed in Settings so low-vision users don't have to fight
  // a fine-grained slider to reach a comfortable size.
  static const double presetNormal = 1.0;
  static const double presetLarge = 1.35;
  static const double presetXLarge = 1.7;

  static const _keyTextScale = 'a11y_text_scale';
  static const _keyHighContrast = 'a11y_high_contrast';
  static const _keyDyslexiaFriendly = 'a11y_dyslexia_friendly';
  static const _keyAutoSpeak = 'a11y_auto_speak';
  static const _keyBoldText = 'a11y_bold_text';

  double _textScale = 1.15;
  bool _highContrast = false;
  bool _dyslexiaFriendly = false;
  bool _autoSpeak = true;
  bool _boldText = false;

  double get textScale => _textScale;
  bool get highContrast => _highContrast;
  bool get dyslexiaFriendly => _dyslexiaFriendly;
  bool get autoSpeak => _autoSpeak;
  bool get boldText => _boldText;

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
    _boldText = prefs.getBool(_keyBoldText) ?? _boldText;
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

  Future<void> setBoldText(bool value) async {
    if (_boldText == value) return;
    _boldText = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBoldText, value);
  }
}
