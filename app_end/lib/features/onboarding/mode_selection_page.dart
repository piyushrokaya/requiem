import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/voice_assistant_service.dart';
import '../../core/state/accessibility_settings.dart';
import '../../core/state/interaction_mode.dart';
import '../../widgets/big_action_button.dart';

class ModeSelectionPage extends StatefulWidget {
  const ModeSelectionPage({super.key});

  @override
  State<ModeSelectionPage> createState() => _ModeSelectionPageState();
}

class _ModeSelectionPageState extends State<ModeSelectionPage> {
  bool _busy = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askAndListen());
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _askAndListen() async {
    if (!mounted || _busy) return;
    _busy = true;

    final voice = context.read<VoiceAssistantService>();

    await voice.stopSpeaking();

    await voice.speakNepaliAndWait(
      'नमस्ते। तपाईं यो एप कसरी प्रयोग गर्न चाहनुहुन्छ? '
      'कृपया भन्नुहोस्: “आवाज मोड” वा “सामान्य मोड”।',
    );

    await voice.startFreeSpeechOnce(
      onText: (text) {
        if (!mounted) return;
        final mode = _parseMode(text);
        if (mode == null) {
          _busy = false;
          voice.speakNepali(
            'माफ गर्नुहोस्, बुझ्न सकिन। '
            'कृपया “आवाज मोड” वा “सामान्य मोड” भन्नुहोस्।',
          );
          _retryTimer?.cancel();
          _retryTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) _askAndListen();
          });
          return;
        }
        _busy = false;
        if (mode == InteractionMode.normal) {
          unawaited(voice.stopSpeaking());
        }
        context.read<AccessibilitySettings>().setAutoSpeak(
          mode == InteractionMode.voiceOnly,
        );
        context.read<InteractionModeController>().choose(mode);
      },
    );

    _busy = false;
  }

  InteractionMode? _parseMode(String spoken) {
    final s = spoken.toLowerCase();

    final isVoice =
        s.contains('आवाज') || s.contains('आवाज मोड') || s.contains('voice');

    final isNormal =
        s.contains('सामान्य') ||
        s.contains('सामान्य मोड') ||
        s.contains('text') ||
        s.contains('ट्याप');

    if (isVoice && !isNormal) return InteractionMode.voiceOnly;
    if (isNormal && !isVoice) return InteractionMode.normal;
    if (isVoice) return InteractionMode.voiceOnly;
    if (isNormal) return InteractionMode.normal;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceAssistantService>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.newspaper,
                    size: 40,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'सङ्क्षेप',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'कृपया आफ्नो प्रयोग मोड छनोट गर्नुहोस्',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  voice.isListening
                      ? 'सुन्दैछ... कृपया बोल्नुहोस्।'
                      : 'माइक अनुमति दिनुहोस् र “आवाज मोड” वा “सामान्य मोड” भन्नुहोस्।',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                BigActionButton(
                  icon: Icons.record_voice_over,
                  title: 'आवाज मोड (Voice Mode)',
                  subtitle: 'आवाजको माध्यमबाट मात्र एप चलाउने',
                  onPressed: () {
                    context.read<AccessibilitySettings>().setAutoSpeak(true);
                    context.read<InteractionModeController>().choose(
                      InteractionMode.voiceOnly,
                    );
                  },
                ),
                const SizedBox(height: 12),
                BigActionButton(
                  icon: Icons.text_fields,
                  title: 'सामान्य मोड (Normal Mode)',
                  subtitle: 'टेक्स्ट र टच प्रयोग गरी एप चलाउने',
                  onPressed: () {
                    unawaited(
                      context.read<VoiceAssistantService>().stopSpeaking(),
                    );
                    context.read<AccessibilitySettings>().setAutoSpeak(false);
                    context.read<InteractionModeController>().choose(
                      InteractionMode.normal,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
