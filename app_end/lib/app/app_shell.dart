import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/voice_assistant_service.dart';
import '../core/state/accessibility_settings.dart';
import '../core/state/interaction_mode.dart';
import '../features/ask/ask_page.dart';
import '../features/compare/compare_page.dart';
import '../features/news/news_page.dart';
import '../features/onboarding/voice_destination_page.dart';
import '../features/settings/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _showVoiceDestination = false;

  static const _titles = <String>['समाचार', 'तुलना', 'सोधपुछ'];

  @override
  void initState() {
    super.initState();
    _showVoiceDestination = context
        .read<InteractionModeController>()
        .isVoiceOnly;
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<InteractionModeController>();
    final voiceOnly = mode.isVoiceOnly;

    // Voice-only mode mirrors sanksep: only News and Compare have guided
    // voice flows. Ask remains a manual-mode-only tab (as in sanksep, where
    // Ask isn't part of the voice navigation story either).
    final pages = voiceOnly
        ? <Widget>[
            VoiceNewsPage(
              onBackToMenu: () {
                setState(() {
                  _showVoiceDestination = true;
                });
              },
            ),
            VoiceComparePage(
              onBackToMenu: () {
                setState(() {
                  _showVoiceDestination = true;
                });
              },
            ),
          ]
        : const <Widget>[NewsPage(), ComparePage(), AskPage()];

    final showingVoiceDestination = voiceOnly && _showVoiceDestination;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          showingVoiceDestination ? 'आवाज नेभिगेसन' : _titles[_index],
        ),
        actions: (showingVoiceDestination || voiceOnly)
            ? null
            : [
                IconButton(
                  tooltip: 'Speak / Voice command',
                  icon: const Icon(Icons.mic),
                  onPressed: () async {
                    final voice = context.read<VoiceAssistantService>();
                    final settings = context.read<AccessibilitySettings>();
                    await voice.startVoiceCommandMode(
                      onText: (text) => _handleVoiceCommand(
                        context,
                        settings: settings,
                        spoken: text,
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Server settings',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
                ),
              ],
      ),
      body: SafeArea(
        child: showingVoiceDestination
            ? VoiceDestinationPage(
                onNavigate: (targetIndex) {
                  setState(() {
                    _index = targetIndex;
                    _showVoiceDestination = false;
                  });

                  // For voice-only mode, the destination page + target page
                  // will handle their own voice prompts.
                  if (!voiceOnly) {
                    final settings = context.read<AccessibilitySettings>();
                    if (settings.autoSpeak) {
                      final title = _titles[targetIndex];
                      context.read<VoiceAssistantService>().speakNepali(
                        '$title खोलियो।',
                      );
                    }
                  }
                },
              )
            : pages[_index],
      ),
      bottomNavigationBar: voiceOnly
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.newspaper_outlined),
                  selectedIcon: Icon(Icons.newspaper),
                  label: 'समाचार',
                ),
                NavigationDestination(
                  icon: Icon(Icons.compare_arrows_outlined),
                  selectedIcon: Icon(Icons.compare_arrows),
                  label: 'तुलना',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat_bubble),
                  label: 'सोधपुछ',
                ),
              ],
            ),
    );
  }

  void _handleVoiceCommand(
    BuildContext context, {
    required AccessibilitySettings settings,
    required String spoken,
  }) {
    final normalized = spoken.trim();

    int? target;
    if (normalized.contains('समाचार') || normalized.contains('news')) {
      target = 0;
    } else if (normalized.contains('तुलना') ||
        normalized.contains('compare')) {
      target = 1;
    } else if (normalized.contains('सोधपुछ') || normalized.contains('ask')) {
      target = 2;
    }

    if (target != null) {
      setState(() => _index = target!);
      if (settings.autoSpeak) {
        context.read<VoiceAssistantService>().speakNepali(
          '${_titles[target]} खोलियो।',
        );
      }
    } else {
      if (settings.autoSpeak) {
        context.read<VoiceAssistantService>().speakNepali(
          'माफ गर्नुहोस्। आदेश बुझिन। उदाहरण: समाचार, तुलना, सोधपुछ।',
        );
      }
    }
  }
}
