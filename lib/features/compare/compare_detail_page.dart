import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/comparison_cluster.dart';
import '../../core/services/voice_assistant_service.dart';
import '../../core/state/accessibility_settings.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(cluster.category)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              cluster.oneLiner,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (cluster.shortSummary.isNotEmpty) ...[
              Text(
                'Short Summary:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(cluster.shortSummary),
              const SizedBox(height: 12),
            ],
            if (cluster.keyPoints.isNotEmpty) ...[
              Text(
                'Key Points:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(cluster.keyPoints),
              const SizedBox(height: 12),
            ],
            if (cluster.coverageBreakdown.isNotEmpty) ...[
              Text(
                'Coverage Breakdown:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(cluster.coverageBreakdown),
              const SizedBox(height: 12),
            ],
            if (cluster.missingInfo.isNotEmpty) ...[
              Text(
                'Missing Info:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(cluster.missingInfo),
            ],
          ],
        ),
      ),
    );
  }
}
