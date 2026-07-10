import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/voice_assistant_service.dart';
import '../../core/state/accessibility_settings.dart';
import '../../widgets/big_action_button.dart';

/// Voice-mode landing page.
///
/// Shows destinations (समाचार/तुलना) and also accepts spoken
/// input to navigate.
class VoiceDestinationPage extends StatefulWidget {
  const VoiceDestinationPage({super.key, required this.onNavigate});

  /// Navigation target index mapping should follow AppShell tab order.
  final ValueChanged<int> onNavigate;

  @override
  State<VoiceDestinationPage> createState() => _VoiceDestinationPageState();
}

class _VoiceDestinationPageState extends State<VoiceDestinationPage> {
  bool _busy = false;
  Timer? _retryTimer;
  VoiceAssistantService? _voice;
  AccessibilitySettings? _settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptAndListen());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _voice ??= context.read<VoiceAssistantService>();
    _settings ??= context.read<AccessibilitySettings>();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    // Best-effort cleanup so we don't keep listening after leaving this page.
    final voice = _voice;
    if (voice != null) {
      unawaited(voice.stopListening());
    }
    super.dispose();
  }

  Future<void> _promptAndListen() async {
    if (!mounted || _busy) return;
    _busy = true;

    final settings = _settings ?? context.read<AccessibilitySettings>();
    final voice = _voice ?? context.read<VoiceAssistantService>();

    await voice.stopSpeaking();

    if (settings.autoSpeak) {
      await voice.speakNepaliAndWait(
        'तपाईं कहाँ जान चाहनुहुन्छ? कृपया भन्नुहोस्: समाचार वा तुलना।',
      );
    }

    await voice.startFreeSpeechOnce(
      onText: (text) {
        if (!mounted) return;
        final target = _parseDestinationIndex(text);
        if (target == null) {
          _busy = false;
          if (settings.autoSpeak) {
            voice.speakNepali(
              'माफ गर्नुहोस्, बुझ्न सकिन। कृपया समाचार वा तुलना भन्नुहोस्।',
            );
          }
          _retryTimer?.cancel();
          _retryTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) _promptAndListen();
          });
          return;
        }
        _busy = false;
        // Make sure we fully stop STT/TTS before leaving this page.
        unawaited(voice.stopListening());
        unawaited(voice.stopSpeaking());
        widget.onNavigate(target);
      },
    );

    _busy = false;
  }

  int? _parseDestinationIndex(String spoken) {
    final s = spoken.trim().toLowerCase();

    final isNews =
        s.contains('समाचार') || s.contains('खबर') || s.contains('news');
    final isCompare = s.contains('तुलना') || s.contains('compare');

    if (isNews && !isCompare) return 0;
    if (isCompare && !isNews) return 1;

    if (isNews) return 0;
    if (isCompare) return 1;

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceAssistantService>();
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Text(
          'कृपया छान्नुहोस्',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              voice.isListening ? Icons.mic : Icons.info_outline,
              size: 18,
              color: voice.isListening ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                voice.isListening
                    ? 'सुन्दैछ... कृपया “समाचार” वा “तुलना” भन्नुहोस्।'
                    : '“समाचार” वा “तुलना” बोल्नुहोस्, वा तलबाट ट्याप गर्नुहोस्।',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        if ((voice.lastHeard ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'सुनेको: ${voice.lastHeard}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 20),
        BigActionButton(
          icon: Icons.newspaper,
          title: 'समाचार',
          subtitle: 'आजका शीर्ष समाचार हेर्न/सुन्न',
          onPressed: () async {
            final v = _voice ?? context.read<VoiceAssistantService>();
            await v.stopListening();
            await v.stopSpeaking();
            widget.onNavigate(0);
          },
        ),
        const SizedBox(height: 12),
        BigActionButton(
          icon: Icons.compare_arrows,
          title: 'तुलना',
          subtitle: 'एउटै विषयका लेखहरूको तुलना',
          onPressed: () async {
            final v = _voice ?? context.read<VoiceAssistantService>();
            await v.stopListening();
            await v.stopSpeaking();
            widget.onNavigate(1);
          },
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: voice.isListening ? null : _promptAndListen,
          icon: const Icon(Icons.mic),
          label: Text(voice.isListening ? 'सुन्दैछ...' : 'फेरि बोल्नुहोस्'),
        ),
      ],
    );
  }
}
