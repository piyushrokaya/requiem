import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/comparison_cluster.dart';
import '../../core/services/compare_repository.dart';
import '../../core/services/voice_assistant_service.dart';
import '../../core/state/accessibility_settings.dart';
import '../../core/utils/category_style.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/big_action_button.dart';
import 'compare_detail_page.dart';

class ComparePage extends StatefulWidget {
  const ComparePage({super.key});

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  late Future<List<ComparisonCluster>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<CompareRepository>().fetchClusters();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ComparisonCluster>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return AsyncErrorView(
            error: snapshot.error!,
            onRetry: () => setState(_load),
          );
        }

        final clusters = snapshot.data ?? [];
        if (clusters.isEmpty) {
          return const Center(child: Text('अहिले तुलना उपलब्ध छैन।'));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: clusters.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final cluster = clusters[index];
            return ClusterCard(
              cluster: cluster,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CompareDetailPage(cluster: cluster),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class ClusterCard extends StatelessWidget {
  const ClusterCard({super.key, required this.cluster, required this.onTap});

  final ComparisonCluster cluster;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = categoryStyleFor(cluster.category);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(style.icon, size: 15, color: style.color),
                        const SizedBox(width: 6),
                        Text(
                          cluster.category,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: style.color,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                cluster.oneLiner,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.source_outlined,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      cluster.sources.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
  late Future<List<ComparisonCluster>> _future;
  List<ComparisonCluster> _clusters = [];

  bool _started = false;
  bool _busy = false;
  Timer? _retryTimer;
  VoiceAssistantService? _voice;
  AccessibilitySettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<CompareRepository>().fetchClusters();

    // Start the voice flow as soon as clusters are available, rather than
    // waiting on build timing (which could miss the first prompt).
    unawaited(
      _future.then((items) {
        if (!mounted) return;
        _clusters = items;
        if (_clusters.isEmpty || _started) return;
        _started = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_startVoiceFlow());
        });
      }),
    );
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

    return FutureBuilder<List<ComparisonCluster>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return AsyncErrorView(
            error: snapshot.error!,
            onRetry: () => setState(() {
              _started = false;
              _load();
            }),
          );
        }

        _clusters = snapshot.data ?? [];
        if (_clusters.isEmpty) {
          return const Center(child: Text('अहिले तुलना उपलब्ध छैन।'));
        }

        // Voice flow is started from _load() when the future completes.

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: _clusters.length + 2,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return BigActionButton(
                icon: Icons.mic,
                title: 'तुलना विषय बोल्नुहोस्',
                subtitle: 'खेलकुद, व्यवसाय, स्वास्थ्य, राजनीति… वा “पछाडि”',
                onPressed: voice.isListening ? null : _promptForCategory,
              );
            }
            if (index == 1) {
              return Text(
                'तुलना',
                style: Theme.of(context).textTheme.titleLarge,
              );
            }
            final c = _clusters[index - 2];
            return ClusterCard(
              cluster: c,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CompareDetailPage(cluster: c),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
