import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/comparison_cluster.dart';
import '../../core/services/voice_assistant_service.dart';
import '../../core/state/accessibility_settings.dart';
import '../../core/utils/category_style.dart';

class CompareDetailPage extends StatefulWidget {
  const CompareDetailPage({
    super.key,
    required this.cluster,
    this.forceAutoRead = false,
  });

  final ComparisonCluster cluster;
  final bool forceAutoRead;

  @override
  State<CompareDetailPage> createState() => _CompareDetailPageState();
}

class _CompareDetailPageState extends State<CompareDetailPage> {
  static const int _maxChunkChars = 900;

  bool _autoReadStarted = false;
  VoiceAssistantService? _voice;
  AccessibilitySettings? _settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _autoRead();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _voice ??= context.read<VoiceAssistantService>();
    _settings ??= context.read<AccessibilitySettings>();
  }

  Future<void> _autoRead() async {
    if (_autoReadStarted) return;
    _autoReadStarted = true;

    final settings = _settings ?? context.read<AccessibilitySettings>();
    if (!widget.forceAutoRead && !settings.autoSpeak) return;

    final voice = _voice ?? context.read<VoiceAssistantService>();
    final c = widget.cluster;

    await voice.stopSpeaking();

    final parts = <String>[
      'तुलना सुरु। विषय: ${_cleanForSpeech(c.category)}।',
      if (c.oneLiner.trim().isNotEmpty) _cleanForSpeech(c.oneLiner),
      if (c.shortSummary.trim().isNotEmpty)
        'सारांश: ${_cleanForSpeech(c.shortSummary)}',
      if (c.keyPoints.trim().isNotEmpty)
        'मुख्य बुँदाहरू: ${_cleanForSpeech(c.keyPoints)}',
      if (c.missingInfo.trim().isNotEmpty)
        'छुटेका जानकारी: ${_cleanForSpeech(c.missingInfo)}',
      if (c.coverageBreakdown.trim().isNotEmpty)
        'कभरेज: ${_cleanForSpeech(c.coverageBreakdown)}',
    ];

    for (final part in parts) {
      final cleaned = part.trim();
      if (cleaned.isEmpty) continue;
      final chunks = _chunkForTts(cleaned, maxChars: _maxChunkChars);
      for (final chunk in chunks) {
        if (chunk.trim().isEmpty) continue;
        await voice.speakNepaliAndWait(chunk);
      }
    }
  }

  String _cleanForSpeech(String input) {
    var s = input;
    s = s.replaceAll(RegExp(r'<[^>]*>'), ' ');
    s = s.replaceAll(RegExp(r'&[#a-zA-Z0-9]+;'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  List<String> _chunkForTts(String text, {required int maxChars}) {
    if (text.length <= maxChars) return [text];

    final chunks = <String>[];
    var remaining = text.trim();

    while (remaining.isNotEmpty) {
      if (remaining.length <= maxChars) {
        chunks.add(_finalizeChunk(remaining));
        break;
      }

      var cut = maxChars;
      final window = remaining.substring(0, maxChars);
      final lastNepaliStop = window.lastIndexOf('।');
      final lastDot = window.lastIndexOf('.');
      final lastQ = window.lastIndexOf('?');
      final lastEx = window.lastIndexOf('!');
      final lastComma = window.lastIndexOf(',');

      final boundary = [
        lastNepaliStop,
        lastDot,
        lastQ,
        lastEx,
        lastComma,
      ].where((i) => i >= 0).fold<int>(-1, (a, b) => a > b ? a : b);

      if (boundary >= (maxChars * 0.55).floor()) {
        cut = boundary + 1;
      } else {
        final lastSpace = window.lastIndexOf(' ');
        if (lastSpace >= (maxChars * 0.55).floor()) {
          cut = lastSpace;
        }
      }

      final chunk = remaining.substring(0, cut).trim();
      chunks.add(_finalizeChunk(chunk));
      remaining = remaining.substring(cut).trim();
    }

    return chunks.where((c) => c.trim().isNotEmpty).toList();
  }

  String _finalizeChunk(String chunk) {
    var c = chunk.trim();
    final trailingNums = RegExp(r'(?:\s+\d+){2,}\s*$');
    if (trailingNums.hasMatch(c)) {
      c = c.replaceAll(trailingNums, '').trim();
    }
    if (c.isNotEmpty && !RegExp(r'[।.!?]$').hasMatch(c)) {
      c = '$c।';
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final cluster = widget.cluster;
    final scheme = Theme.of(context).colorScheme;
    final style = categoryStyleFor(cluster.category);

    return Scaffold(
      appBar: AppBar(title: const Text('तुलना')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
            ],
          ),
          const SizedBox(height: 12),
          Text(
            cluster.oneLiner,
            style: Theme.of(context).textTheme.headlineSmall,
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (cluster.shortSummary.isNotEmpty)
            _Section(
              icon: Icons.summarize_outlined,
              title: 'सारांश',
              body: cluster.shortSummary,
            ),
          if (cluster.keyPoints.isNotEmpty)
            _Section(
              icon: Icons.checklist_outlined,
              title: 'मुख्य बुँदाहरू',
              body: cluster.keyPoints,
            ),
          if (cluster.coverageBreakdown.isNotEmpty)
            _Section(
              icon: Icons.pie_chart_outline,
              title: 'कभरेज',
              body: cluster.coverageBreakdown,
            ),
          if (cluster.missingInfo.isNotEmpty)
            _Section(
              icon: Icons.info_outline,
              title: 'छुटेका जानकारी',
              body: cluster.missingInfo,
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
