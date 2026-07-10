import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/news_article.dart';
import '../../core/services/news_repository.dart';
import '../../core/services/voice_assistant_service.dart';
import '../../core/state/accessibility_settings.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/big_action_button.dart';
import '../article/article_detail_page.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  static const int _maxNewsItems = 10;

  late Future<List<NewsArticle>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<NewsRepository>().getTopArticles(
      limit: _maxNewsItems,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NewsArticle>>(
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

        final articles = (snapshot.data ?? []).take(_maxNewsItems).toList();
        if (articles.isEmpty) {
          return const Center(child: Text('अहिले समाचार उपलब्ध छैन।'));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: articles.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Text(
                'शीर्ष समाचार',
                style: Theme.of(context).textTheme.titleLarge,
              );
            }
            final a = articles[index - 1];
            return ArticleCard(
              article: a,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ArticleDetailPage(article: a),
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

class ArticleCard extends StatelessWidget {
  const ArticleCard({super.key, required this.article, required this.onTap});

  final NewsArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.newspaper,
                  color: scheme.onPrimaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          article.source,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          '  •  ${_relativeTime(article.publishedAt)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
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

class VoiceNewsPage extends StatefulWidget {
  const VoiceNewsPage({super.key, required this.onBackToMenu});

  final VoidCallback onBackToMenu;

  @override
  State<VoiceNewsPage> createState() => _VoiceNewsPageState();
}

class _VoiceNewsPageState extends State<VoiceNewsPage> {
  static const int _maxNewsItems = 10;

  late Future<List<NewsArticle>> _future;
  List<NewsArticle> _articles = [];

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
    _future = context.read<NewsRepository>().getTopArticles(
      limit: _maxNewsItems,
    );

    // Start the voice flow as soon as articles are available, rather than
    // waiting on build timing (which could miss the first prompt).
    unawaited(
      _future.then((items) {
        if (!mounted) return;
        _articles = items.take(_maxNewsItems).toList();
        if (_articles.isEmpty || _started) return;
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
    if (!mounted || _busy || _articles.isEmpty) return;
    _busy = true;

    final voice = _voice ?? context.read<VoiceAssistantService>();

    await voice.stopListening();
    await voice.stopSpeaking();
    await _readHeadlinesThenAsk();
    _busy = false;
  }

  Future<void> _readHeadlinesThenAsk() async {
    if (!mounted || _articles.isEmpty) return;
    final voice = _voice ?? context.read<VoiceAssistantService>();

    await voice.stopListening();
    await voice.stopSpeaking();

    await voice.speakNepaliAndWait('आजका शीर्ष समाचार:');
    for (int i = 0; i < _articles.length; i++) {
      final title = _cleanForSpeech(_articles[i].title, maxWords: 22);
      await voice.speakNepaliAndWait('${_toNepaliNumber(i + 1)}. $title');
    }

    await voice.speakNepaliAndWait(
      'कृपया कुन नम्बरको समाचार पढेर सुनाऊँ? '
      'पछाडि जान “पछाडि” भन्नुहोस्।',
    );

    await voice.startFreeSpeechOnce(onText: _handleChoice);
  }

  Future<void> _promptForNewsNumber() async {
    if (!mounted || _articles.isEmpty) return;
    // Manual button should replay the whole list + prompt.
    await _readHeadlinesThenAsk();
  }

  String _toNepaliNumber(int n) {
    final s = n.toString();
    return s
        .replaceAll('0', '०')
        .replaceAll('1', '१')
        .replaceAll('2', '२')
        .replaceAll('3', '३')
        .replaceAll('4', '४')
        .replaceAll('5', '५')
        .replaceAll('6', '६')
        .replaceAll('7', '७')
        .replaceAll('8', '८')
        .replaceAll('9', '९');
  }

  Future<void> _handleChoice(String text) async {
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

    final choice = _parseSpokenNumber(normalized);
    if (choice == null || choice < 1 || choice > _articles.length) {
      voice.speakNepali(
        'माफ गर्नुहोस्, नम्बर बुझिन। कृपया १ देखि ${_articles.length} सम्मको नम्बर भन्नुहोस्, वा पछाडि भन्नुहोस्।',
      );

      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          _promptForNewsNumber();
        }
      });
      return;
    }

    final selected = _articles[choice - 1];
    await voice.stopSpeaking();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ArticleDetailPage(article: selected, forceAutoRead: true),
      ),
    );

    if (!mounted) return;

    // After reading one article, return to the list and ask again.
    await _readHeadlinesThenAsk();
  }

  bool _isBackCommand(String s) {
    return s.contains('पछाडि') ||
        s.contains('पछाडी') ||
        s.contains('back') ||
        s.contains('go back');
  }

  int? _parseSpokenNumber(String spoken) {
    // Convert Nepali digits to ASCII digits.
    final mapped = spoken
        .replaceAll('०', '0')
        .replaceAll('१', '1')
        .replaceAll('२', '2')
        .replaceAll('३', '3')
        .replaceAll('४', '4')
        .replaceAll('५', '5')
        .replaceAll('६', '6')
        .replaceAll('७', '7')
        .replaceAll('८', '8')
        .replaceAll('९', '9');

    final digitMatch = RegExp(r'\d+').firstMatch(mapped);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(0)!);
    }

    // Basic Nepali number words (1-20).
    const wordMap = <String, int>{
      'एक': 1,
      'पहिलो': 1,
      'दुई': 2,
      'दोश्रो': 2,
      'दोस्रो': 2,
      'तेस्रो': 3,
      'तीन': 3,
      'चार': 4,
      'पाँच': 5,
      'पाच': 5,
      'छ': 6,
      'सात': 7,
      'आठ': 8,
      'नौ': 9,
      'दस': 10,
      'दश': 10,
      'एघार': 11,
      'एघारौँ': 11,
      'बाह्र': 12,
      'तेह्र': 13,
      'चौध': 14,
      'पन्ध्र': 15,
      'सोह्र': 16,
      'सत्र': 17,
      'अठार': 18,
      'उन्नाइस': 19,
      'बीस': 20,
    };

    for (final entry in wordMap.entries) {
      if (spoken.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  String _cleanForSpeech(String input, {int? maxWords}) {
    var s = input;
    // Remove HTML tags.
    s = s.replaceAll(RegExp(r'<[^>]*>'), ' ');
    // Remove HTML entities like &nbsp; and numeric entities like &#8230;
    s = s.replaceAll(RegExp(r'&[#a-zA-Z0-9]+;'), ' ');
    // Collapse whitespace.
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (maxWords != null && maxWords > 0) {
      final words = s.split(' ');
      if (words.length > maxWords) {
        s = words.take(maxWords).join(' ').trim();
      }
    }

    return s;
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceAssistantService>();

    return FutureBuilder<List<NewsArticle>>(
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

        _articles = (snapshot.data ?? []).take(_maxNewsItems).toList();
        if (_articles.isEmpty) {
          return const Center(child: Text('अहिले समाचार उपलब्ध छैन।'));
        }

        // Voice flow is started from initState when the future completes.

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: _articles.length + 2,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return BigActionButton(
                icon: Icons.mic,
                title: 'समाचार नम्बर बोल्नुहोस्',
                subtitle: 'उदाहरण: १, २, ३… वा “पछाडि”',
                onPressed: voice.isListening ? null : _promptForNewsNumber,
              );
            }
            if (index == 1) {
              return Text(
                'शीर्ष समाचार',
                style: Theme.of(context).textTheme.titleLarge,
              );
            }
            final a = _articles[index - 2];
            return ArticleCard(
              article: a,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ArticleDetailPage(article: a),
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
