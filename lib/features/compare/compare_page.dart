import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/data/dummy_data.dart';
import '../../core/models/comparison_cluster.dart';
import '../../core/services/voice_assistant_service.dart';
import '../../core/state/accessibility_settings.dart';
import '../../widgets/big_action_button.dart';
import 'compare_detail_page.dart';

class ComparePage extends StatelessWidget {
  const ComparePage({super.key});

  @override
  Widget build(BuildContext context) {
    final clusters = dummyClusters;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: clusters.length,
      itemBuilder: (context, index) {
        final cluster = clusters[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CompareDetailPage(cluster: cluster),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cluster.category,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(cluster.oneLiner),
                  const SizedBox(height: 8),
                  Text('Sources: ${cluster.sources.join(', ')}'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class VoiceComparePage extends StatefulWidget {
  const VoiceComparePage({super.key, required this.onBackToMenu});

  final VoidCallback onBackToMenu;

  @override
  State<VoiceComparePage> createState() => _VoiceComparePageState();
}

class _VoiceComparePageState extends State<VoiceComparePage> {
  final List<ComparisonCluster> _clusters = dummyClusters;

  bool _started = false;
  bool _busy = false;
  Timer? _retryTimer;
  VoiceAssistantService? _voice;
  AccessibilitySettings? _settings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _voice ??= context.read<VoiceAssistantService>();
    _settings ??= context.read<AccessibilitySettings>();

    if (!_started && _clusters.isNotEmpty) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_startVoiceFlow());
        }
      });
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    final voice = _voice;
    if (voice != null) {
      unawaited(voice.stopListening());
    }
    super.dispose();
  }

  Future<void> _startVoiceFlow() async {
    if (!mounted || _busy || _clusters.isEmpty) return;
    _busy = true;

    final voice = _voice ?? context.read<VoiceAssistantService>();
    await voice.stopListening();
    await voice.stopSpeaking();
    await _promptForCategory();
    _busy = false;
  }

  Future<void> _promptForCategory() async {
    if (!mounted || _clusters.isEmpty) return;
    final voice = _voice ?? context.read<VoiceAssistantService>();

    await voice.stopListening();
    await voice.stopSpeaking();
    await voice.speakNepaliAndWait(
      'कुन विषयको तुलना सुन्न चाहनुहुन्छ? '
      'कृपया भन्नुहोस्: खेलकुद, व्यवसाय, स्वास्थ्य, वा राजनीति। '
      'पछाडि जान “पछाडि” भन्नुहोस्।',
    );

    await voice.startFreeSpeechOnce(onText: _handleCategoryChoice);
  }

  Future<void> _handleCategoryChoice(String text) async {
    if (!mounted) return;

    final voice = _voice ?? context.read<VoiceAssistantService>();
    final normalized = text.trim().toLowerCase();

    // Ensure STT is fully stopped before we potentially navigate.
    await voice.stopListening();
    if (!mounted) return;

    if (_isBackCommand(normalized)) {
      widget.onBackToMenu();
      return;
    }

    final category = _parseCategory(normalized);
    if (category == null) {
      voice.speakNepali(
        'माफ गर्नुहोस्, बुझ्न सकिन। कृपया खेलकुद, व्यवसाय, स्वास्थ्य, वा राजनीति भन्नुहोस्, वा पछाडि भन्नुहोस्।',
      );

      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          _promptForCategory();
        }
      });
      return;
    }

    final match = _clusters.where((c) => c.category == category).toList();
    if (match.isEmpty) {
      voice.speakNepali(
        'यो विषयको तुलना अहिले उपलब्ध छैन। अर्को विषय भन्नुहोस्, वा पछाडि भन्नुहोस्।',
      );
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          _promptForCategory();
        }
      });
      return;
    }

    final cluster = match.first;
    await voice.stopSpeaking();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CompareDetailPage(cluster: cluster, forceAutoRead: true),
      ),
    );

    if (!mounted) return;

    // After reading one category detail, ask again.
    await _promptForCategory();
  }

  String? _parseCategory(String s) {
    final sports =
        s.contains('खेल') ||
        s.contains('खेलकुद') ||
        s.contains('khel') ||
        s.contains('sports');
    final business =
        s.contains('व्यवसाय') ||
        s.contains('अर्थ') ||
        s.contains('ब्यापार') ||
        s.contains('byabas') ||
        s.contains('business');
    final health =
        s.contains('स्वास्थ्य') ||
        s.contains('स्वास्थ') ||
        s.contains('swasth') ||
        s.contains('health');
    final politics =
        s.contains('राजनीति') ||
        s.contains('राजनिति') ||
        s.contains('rajniti') ||
        s.contains('politics');

    if (sports && !business && !health && !politics) return 'Sports';
    if (business && !sports && !health && !politics) return 'Business';
    if (health && !sports && !business && !politics) return 'Health';
    if (politics && !sports && !business && !health) return 'Politics';

    if (sports) return 'Sports';
    if (business) return 'Business';
    if (health) return 'Health';
    if (politics) return 'Politics';
    return null;
  }

  bool _isBackCommand(String s) {
    return s.contains('पछाडि') ||
        s.contains('पछाडी') ||
        s.contains('back') ||
        s.contains('go back');
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceAssistantService>();

    if (_clusters.isEmpty) {
      return const Center(child: Text('अहिले तुलना उपलब्ध छैन।'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BigActionButton(
          icon: Icons.mic,
          title: 'तुलना विषय बोल्नुहोस्',
          subtitle: 'खेलकुद, व्यवसाय, स्वास्थ्य, राजनीति… वा “पछाडि”',
          onPressed: voice.isListening ? null : _promptForCategory,
        ),
        const SizedBox(height: 16),
        Text('तुलना', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ..._clusters.map(
          (c) => Card(
            child: ListTile(
              title: Text(c.category),
              subtitle: Text(c.oneLiner),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CompareDetailPage(cluster: c),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
