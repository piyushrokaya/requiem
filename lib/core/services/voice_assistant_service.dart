import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceAssistantService extends ChangeNotifier {
  final stt.SpeechToText _stt = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _speechInitialized = false;

  bool _isListening = false;
  bool get isListening => _isListening;

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  String? _lastHeard;
  String? get lastHeard => _lastHeard;

  Future<void> speakNepali(String text) async {
    _isSpeaking = true;
    notifyListeners();
    try {
      await _tts.setLanguage('ne-NP');
      await _tts.setSpeechRate(0.48);
      await _tts.awaitSpeakCompletion(false);
      await _tts.speak(text);
    } finally {
      _isSpeaking = false;
      notifyListeners();
    }
  }

  Future<void> speakNepaliAndWait(String text) async {
    _isSpeaking = true;
    notifyListeners();
    try {
      await _tts.setLanguage('ne-NP');
      await _tts.setSpeechRate(0.48);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(text);
    } finally {
      _isSpeaking = false;
      notifyListeners();
      // Reset to non-blocking for future calls.
      await _tts.awaitSpeakCompletion(false);
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  /// Starts a short listening session to interpret a navigation command.
  Future<void> startVoiceCommandMode({
    required ValueChanged<String> onText,
  }) async {
    if (_isListening) {
      await stopListening();
    }

    final available = await _ensureSpeechInitialized();
    if (!available) {
      return;
    }

    _isListening = true;
    _lastHeard = null;
    notifyListeners();

    await _stt.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: 'ne_NP',
        listenMode: stt.ListenMode.confirmation,
      ),
      onResult: (result) {
        if (!result.finalResult) return;
        _lastHeard = result.recognizedWords;
        // Stop listening before handing control back to UI.
        // This avoids races where the UI navigates while STT is still active.
        stopListening();
        onText(result.recognizedWords);
      },
    );
  }

  /// Listen for a single free-form reply (e.g. onboarding answer).
  Future<void> startFreeSpeechOnce({
    required ValueChanged<String> onText,
  }) async {
    if (_isListening) {
      await stopListening();
    }

    final available = await _ensureSpeechInitialized();
    if (!available) return;

    _isListening = true;
    _lastHeard = null;
    notifyListeners();

    await _stt.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: 'ne_NP',
        listenMode: stt.ListenMode.dictation,
        partialResults: false,
      ),
      onResult: (result) {
        if (!result.finalResult) return;
        _lastHeard = result.recognizedWords;
        stopListening();
        onText(result.recognizedWords);
      },
    );
  }

  Future<bool> _ensureSpeechInitialized() async {
    if (_speechInitialized) {
      return _stt.isAvailable;
    }
    final available = await _stt.initialize(
      onStatus: (status) {
        // Common statuses: listening, notListening, done.
        // When STT stops, keep our state consistent.
        if (status == 'done' || status == 'notListening') {
          if (_isListening) {
            _isListening = false;
            notifyListeners();
          }
        }
      },
      onError: (_) {
        if (_isListening) {
          _isListening = false;
          notifyListeners();
        }
      },
    );
    _speechInitialized = true;
    return available;
  }

  Future<void> stopListening() async {
    // Always try to stop at the platform layer even if our internal flag is
    // out of sync (which can happen if STT stops itself via timeout/error).
    try {
      await _stt.stop();
    } catch (_) {
      // Ignore platform stop failures; we still reset internal state.
    }
    _isListening = false;
    notifyListeners();
  }
}
