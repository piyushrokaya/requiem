import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/news_article.dart';
import '../../core/services/voice_assistant_service.dart';
import '../../core/state/accessibility_settings.dart';

class ArticleDetailPage extends StatefulWidget {
  const ArticleDetailPage({
    super.key,
    required this.article,
    this.forceAutoRead = false,
  });

  final NewsArticle article;
  final bool forceAutoRead;

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
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
    final a = widget.article;

    final toRead = (a.fullText ?? '').trim().isNotEmpty
        ? a.fullText!
        : a.summary;
    await voice.stopSpeaking();

    final cleaned = _cleanForSpeech(toRead);
    final chunks = _chunkForTts(cleaned, maxChars: _maxChunkChars);
    for (final chunk in chunks) {
      if (chunk.trim().isEmpty) continue;
      await voice.speakNepaliAndWait(chunk);
    }
  }

  String _cleanForSpeech(String input) {
    var s = input;
    s = s.replaceAll(RegExp(r'<[^>]*>'), ' ');
    s = s.replaceAll(RegExp(r'&[#a-zA-Z0-9]+;'), ' ');
    // Strip common footnote markers.
    s = s.replaceAll(RegExp(r'\[\s*\d+\s*\]'), ' ');
    s = s.replaceAll(RegExp(r'\(\s*\d+\s*\)'), ' ');
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
      // Prefer cutting at sentence boundaries.
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
    // If a chunk ends with stray index numbers like "1 2 3", drop them.
    final trailingNums = RegExp(r'(?:\s+\d+){2,}\s*$');
    if (trailingNums.hasMatch(c)) {
      c = c.replaceAll(trailingNums, '').trim();
    }
    // Ensure we don't end mid-token too abruptly.
    if (c.isNotEmpty && !RegExp(r'[।.!?]$').hasMatch(c)) {
      c = '$c।';
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.article;
    final scheme = Theme.of(context).colorScheme;
    final bodyText = (a.fullText ?? '').trim().isNotEmpty
        ? a.fullText!
        : a.summary;

    return Scaffold(
      appBar: AppBar(title: const Text('समाचार')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(a.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  a.source,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.schedule,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _relativeTime(a.publishedAt),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                bodyText,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('पछाडि जानुहोस्'),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} मिनेट अघि';
    if (diff.inHours < 24) return '${diff.inHours} घण्टा अघि';
    return '${diff.inDays} दिन अघि';
  }
}
