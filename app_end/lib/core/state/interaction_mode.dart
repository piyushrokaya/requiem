import 'package:flutter/foundation.dart';

enum InteractionMode { normal, voiceOnly }

class InteractionModeController extends ChangeNotifier {
  InteractionMode? _mode;

  InteractionMode? get mode => _mode;
  bool get isChosen => _mode != null;
  bool get isVoiceOnly => _mode == InteractionMode.voiceOnly;

  void choose(InteractionMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }
}
