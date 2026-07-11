import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/api_config.dart';
import '../../core/services/api_endpoint_store.dart';
import '../../core/state/accessibility_settings.dart';
import '../../core/state/interaction_mode.dart';
import 'dev_server_scanner_page.dart';

/// Lets a developer point the app at a different backend — a LAN IP when
/// testing on a physical device, or a tunnel URL — without rebuilding.
/// Defaults to [ApiConfig.baseUrl] when nothing is saved.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _controller = TextEditingController();
  late Future<String> _resolvedUrl;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _resolvedUrl = ApiEndpointStore.serverBaseUrl();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final normalized = ApiEndpointStore.normalizeServerBaseUrl(raw);
    if (normalized == null) {
      setState(() {
        _saving = false;
        _error = 'मान्य URL होइन। उदाहरण: http://192.168.1.50:5000';
      });
      return;
    }

    await ApiEndpointStore.setOverrideServerBaseUrl(normalized);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _resolvedUrl = ApiEndpointStore.serverBaseUrl();
      _controller.clear();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Server set: $normalized')));
  }

  Future<void> _reset() async {
    await ApiEndpointStore.clearOverrideServerBaseUrl();
    if (!mounted) return;
    setState(() => _resolvedUrl = ApiEndpointStore.serverBaseUrl());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Server reset to default: ${ApiConfig.baseUrl}')),
    );
  }

  Future<void> _scan() async {
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const DevServerScannerPage()));
    if (!mounted) return;
    if (result == null) return;
    setState(() => _resolvedUrl = ApiEndpointStore.serverBaseUrl());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Server set: $result')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AccessibilitySettings>();
    final mode = context.watch<InteractionModeController>();

    return Scaffold(
      appBar: AppBar(title: const Text('सेटिङ')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'पहुँच (Accessibility)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'पाठ आकार: ${(settings.textScale * 100).round()}%',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _sizePreset(context, settings, 'सामान्य',
                  AccessibilitySettings.presetNormal),
              _sizePreset(context, settings, 'ठूलो',
                  AccessibilitySettings.presetLarge),
              _sizePreset(context, settings, 'धेरै ठूलो',
                  AccessibilitySettings.presetXLarge),
            ],
          ),
          Slider(
            value: settings.textScale,
            min: AccessibilitySettings.minTextScale,
            max: AccessibilitySettings.maxTextScale,
            divisions: 23,
            label: '${(settings.textScale * 100).round()}%',
            onChanged: (value) => settings.setTextScale(value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.boldText,
            title: const Text('बाक्लो अक्षर (Bold text)'),
            subtitle: const Text('अक्षर मोटो बनाई सजिलो पढ्न'),
            onChanged: (value) => settings.setBoldText(value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.highContrast,
            title: const Text('उच्च कन्ट्रास्ट (High contrast)'),
            subtitle: const Text('कम दृष्टि भएका प्रयोगकर्ताका लागि'),
            onChanged: (value) => settings.setHighContrast(value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.dyslexiaFriendly,
            title: const Text('पढ्न सजिलो स्पेसिङ (Dyslexia-friendly)'),
            subtitle: const Text('बढी letter/line spacing लगाउँछ'),
            onChanged: (value) => settings.setDyslexiaFriendly(value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.autoSpeak,
            title: const Text('स्वतः पढेर सुनाउनुहोस् (Auto speak)'),
            subtitle: const Text('लेख खोल्दा आफै पढ्न थाल्छ'),
            onChanged: (value) => settings.setAutoSpeak(value),
          ),
          const SizedBox(height: 24),
          Text(
            'प्रयोग मोड (Mode)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'जहिलेसुकै यहाँबाट मोड परिवर्तन गर्न सक्नुहुन्छ।',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          _modeTile(
            context,
            icon: Icons.text_fields,
            title: 'सामान्य मोड',
            subtitle: 'टेक्स्ट र टच प्रयोग गरी',
            selected: !mode.isVoiceOnly,
            onTap: () => _switchMode(InteractionMode.normal),
          ),
          const SizedBox(height: 8),
          _modeTile(
            context,
            icon: Icons.record_voice_over,
            title: 'आवाज मोड',
            subtitle: 'आवाजको माध्यमबाट मात्र',
            selected: mode.isVoiceOnly,
            onTap: () => _switchMode(InteractionMode.voiceOnly),
          ),
          const SizedBox(height: 28),
          Text(
            'Backend server',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'यो app ले समाचार र तुलना डेटा ल्याउने backend server को ठेगाना। '
            'डिफल्टमा emulator/simulator मार्फत यही computer मा चलिरहेको server खोजिन्छ।',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          FutureBuilder<String>(
            future: _resolvedUrl,
            builder: (context, snapshot) {
              final url = snapshot.data ?? '…';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.dns_outlined, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          url,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Override',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'http://192.168.1.50:5000',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _reset,
                  child: const Text('Reset to default'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan server URL'),
          ),
        ],
      ),
    );
  }

  Widget _sizePreset(
    BuildContext context,
    AccessibilitySettings settings,
    String label,
    double value,
  ) {
    final selected = (settings.textScale - value).abs() < 0.001;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => settings.setTextScale(value),
    );
  }

  Widget _modeTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      child: ListTile(
        leading: Icon(
          icon,
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(
          selected ? Icons.check_circle : Icons.radio_button_unchecked,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _switchMode(InteractionMode target) async {
    final modeCtrl = context.read<InteractionModeController>();
    if (modeCtrl.mode == target) return;

    final settings = context.read<AccessibilitySettings>();
    // Match onboarding: voice mode implies auto-speak on, normal implies off.
    await settings.setAutoSpeak(target == InteractionMode.voiceOnly);
    await modeCtrl.choose(target);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          target == InteractionMode.voiceOnly
              ? 'आवाज मोडमा बदलियो'
              : 'सामान्य मोडमा बदलियो',
        ),
      ),
    );
  }
}
