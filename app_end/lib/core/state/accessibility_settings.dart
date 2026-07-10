import 'package:flutter/foundation.dart';

class AccessibilitySettings extends ChangeNotifier {
  bool _largeText = true;
  bool _autoSpeak = true;

  bool get largeText => _largeText;
  bool get autoSpeak => _autoSpeak;

  void setLargeText(bool value) {
    if (_largeText == value) return;
    _largeText = value;
    notifyListeners();
  }

  void setAutoSpeak(bool value) {
    if (_autoSpeak == value) return;
    _autoSpeak = value;
    notifyListeners();
  }
}
