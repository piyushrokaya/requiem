import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum InteractionMode { normal, voiceOnly }

class InteractionModeController extends ChangeNotifier {
  static const _keyMode = 'interaction_mode';

  InteractionMode? _mode;

  InteractionMode? get mode => _mode;
  bool get isChosen => _mode != null;
  bool get isVoiceOnly => _mode == InteractionMode.voiceOnly;

  /// Loads a previously-chosen mode, if any, so returning users aren't asked
  /// again on every launch.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyMode);
    if (stored == InteractionMode.normal.name) {
      _mode = InteractionMode.normal;
    } else if (stored == InteractionMode.voiceOnly.name) {
      _mode = InteractionMode.voiceOnly;
    }
    notifyListeners();
  }

  Future<void> choose(InteractionMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, mode.name);
  }

  /// Clears the saved choice so the mode-selection screen is shown again.
  Future<void> reset() async {
    _mode = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyMode);
  }
}
