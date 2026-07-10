import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/news_article.dart';
import '../../core/services/news_repository.dart';
import '../../core/services/voice_assistant_service.dart';
import '../../core/state/accessibility_settings.dart';
import '../../core/utils/category_style.dart';
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
  static const _keyPreferredCategory = 'preferred_news_category';

  late Future<List<NewsArticle>> _future;
  List<String> _categories = [];
  String? _selectedCategory;
  bool _showingCached = false;

  @override
  void initState() {
    super.initState();
    // Assign _future synchronously so the first build (before the persisted
    // preference below has loaded) always has a future to show a spinner for.
    _load();
    _loadPreferredCategoryThenCategories();
  }

  Future<void> _loadPreferredCategoryThenCategories() async {
    final repo = context.read<NewsRepository>();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final preferred = prefs.getString(_keyPreferredCategory);
    if (preferred != null) {
      setState(() {
        _selectedCategory = preferred;
        _load();
      });
    }

    unawaited(
      repo.getCategories().then((cats) {
        if (mounted) setState(() => _categories = cats);
      }).catchError((_) {}),
    );
  }

  void _load() {
    final repo = context.read<NewsRepository>();
    _future = repo.getTopArticles(
      limit: _maxNewsItems,
      category: _selectedCategory,
    );
    unawaited(
      _future
          .then((_) {
            if (mounted) {
              setState(() => _showingCached = repo.lastFetchWasFromCache);
            }
          })
          .catchError((_) {
            // Ignored here; the FutureBuilder below surfaces the error.
          }),
    );
  }

  Future<void> _selectCategory(String? category) async {
    if (_selectedCategory == category) return;
    setState(() {
      _selectedCategory = category;
      _load();
    });
    final prefs = await SharedPreferences.getInstance();
    if (category == null) {
      await prefs.remove(_keyPreferredCategory);
    } else {
      await prefs.setString(_keyPreferredCategory, category);
    }
  }

  Widget _buildCategoryChips() {
    if (_categories.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('सबै'),
            selected: _selectedCategory == null,
            onSelected: (_) => unawaited(_selectCategory(null)),
          ),
          for (final c in _categories)
            ChoiceChip(
              avatar: Icon(categoryStyleFor(c).icon, size: 16),
              label: Text(categoryLabelNepali(c)),
              selected: _selectedCategory == c,
              onSelected: (_) => unawaited(_selectCategory(c)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCategoryChips(),
        Expanded(
          child: FutureBuilder<List<NewsArticle>>(
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

              final articles = (snapshot.data ?? [])
                  .take(_maxNewsItems)
                  .toList();

              return RefreshIndicator(
                onRefresh: () async {
                  setState(_load);
                  await _future;
                },
                child: articles.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(child: Text('अहिले समाचार उपलब्ध छैन।')),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: articles.length + (_showingCached ? 2 : 1),
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Text(
                              'शीर्ष समाचार',
                              style: Theme.of(context).textTheme.titleLarge,
                            );
                          }
                          if (_showingCached && index == 1) {
                            return const _CachedNewsBanner();
                          }
                          final offset = _showingCached ? 2 : 1;
                          final a = articles[index - offset];
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
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CachedNewsBanner extends StatelessWidget {
  const _CachedNewsBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'सर्भरसँग जोड्न सकिएन। सेभ गरिएको (offline) समाचार देखाइँदैछ।',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
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

  Future<List<NewsArticle>>? _future;
  List<NewsArticle> _articles = [];
  List<String> _categories = [];
  String? _category;
  bool _categoryChosen = false;
  bool _loadingCategories = true;

  bool _busy = false;
  Timer? _retryTimer;
  VoiceAssistantService? _voice;
  AccessibilitySettings? _settings;

  @override
  void initState() {
    super.initState();
    _initCategoriesThenPrompt();
  }

  Future<void> _initCategoriesThenPrompt() async {
    final repo = context.read<NewsRepository>();
    try {
      _categories = await repo.getCategories();
    } catch (_) {
      _categories = [];
    }
    if (!mounted) return;
    setState(() => _loadingCategories = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_promptForCategory());
    });
  }

  void _loadArticles(String? category) {
    _category = category;
    _categoryChosen = true;
    _future = context.read<NewsRepository>().getTopArticles(
      limit: _maxNewsItems,
      category: category,
    );

    unawaited(
      _future!
          .then((items) async {
            if (!mounted) return;
            setState(() {
              _articles = items.take(_maxNewsItems).toList();
            });
            if (_articles.isEmpty) {
              final voice = _voice ?? context.read<VoiceAssistantService>();
              await voice.speakNepaliAndWait(
                'यो विषयमा अहिले समाचार उपलब्ध छैन। अर्को विषय भन्नुहोस्।',
              );
              if (mounted) unawaited(_promptForCategory());
              return;
            }
            await _readHeadlinesThenAsk();
          })
          .catchError((_) {
            // Ignored here; the FutureBuilder below surfaces the error.
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

  Future<void> _promptForCategory() async {
    if (!mounted || _busy) return;
    _busy = true;

    final voice = _voice ?? context.read<VoiceAssistantService>();
    await voice.stopListening();
    await voice.stopSpeaking();

    final options = _categories.map(categoryLabelNepali).join(', ');
    await voice.speakNepaliAndWait(
      _categories.isEmpty
          ? 'समाचार लोड हुँदैछ। कृपया पर्खनुहोस्, वा “सबै” भन्नुहोस्।'
          : 'कुन विषयको समाचार सुन्न चाहनुहुन्छ? $options, वा “सबै” भन्नुहोस्। '
                'पछाडि जान “पछाडि” भन्नुहोस्।',
    );

    await voice.startFreeSpeechOnce(onText: _handleCategoryChoice);
    _busy = false;
  }

  Future<void> _handleCategoryChoice(String text) async {
    if (!mounted) return;
    final voice = _voice ?? context.read<VoiceAssistantService>();
    final normalized = text.trim().toLowerCase();

    await voice.stopListening();
    if (!mounted) return;

    if (_isBackCommand(normalized)) {
      widget.onBackToMenu();
      return;
    }

    if (normalized.contains('सबै') || normalized.contains('all')) {
      await voice.stopSpeaking();
      if (!mounted) return;
      _loadArticles(null);
      return;
    }

    final category = _parseCategoryKey(normalized);
    if (category == null) {
      voice.speakNepali('माफ गर्नुहोस्, बुझ्न सकिन। कृपया फेरि भन्नुहोस्।');
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) unawaited(_promptForCategory());
      });
      return;
    }

    await voice.stopSpeaking();
    if (!mounted) return;
    _loadArticles(category);
  }

  String? _parseCategoryKey(String spoken) {
    const keywordMap = <String, List<String>>{
      'Politics': ['राजनीति', 'राजनिति', 'rajniti', 'politics'],
      'Business': ['व्यापार', 'व्यवसाय', 'अर्थ', 'byabas', 'business'],
      'Sports': ['खेलकुद', 'खेल', 'khel', 'sports'],
      'Health': ['स्वास्थ्य', 'स्वास्थ', 'swasth', 'health'],
      'Crime': ['अपराध', 'aparadh', 'crime'],
      'Entertainment': ['मनोरञ्जन', 'मनोरन्जन', 'manoranjan', 'entertainment'],
      'General': ['सामान्य', 'general'],
    };

    for (final entry in keywordMap.entries) {
      final isAvailable = _categories.any(
        (c) => c.toLowerCase() == entry.key.toLowerCase(),
      );
      if (isAvailable && entry.value.any((kw) => spoken.contains(kw))) {
        return entry.key;
      }
    }
    return null;
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
      // One level of "back" returns to category selection; the menu itself
      // is reachable via the explicit back button in the UI.
      await voice.stopSpeaking();
      if (mounted) unawaited(_promptForCategory());
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

  Widget _backButton() {
    return OutlinedButton.icon(
      onPressed: widget.onBackToMenu,
      icon: const Icon(Icons.arrow_back),
      label: const Text('पछाडि (मेनुमा फर्कनुहोस्)'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceAssistantService>();

    if (!_categoryChosen) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _backButton(),
          const SizedBox(height: 16),
          Text(
            'कुन विषयको समाचार सुन्न चाहनुहुन्छ?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (_loadingCategories)
            const Center(child: CircularProgressIndicator())
          else ...[
            BigActionButton(
              icon: Icons.mic,
              title: 'विषय बोल्नुहोस्',
              subtitle: 'उदाहरण: राजनीति, खेलकुद… वा “सबै”',
              onPressed: voice.isListening ? null : _promptForCategory,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _loadArticles(null),
                  child: const Text('सबै'),
                ),
                for (final c in _categories)
                  OutlinedButton(
                    onPressed: () => _loadArticles(c),
                    child: Text(categoryLabelNepali(c)),
                  ),
              ],
            ),
          ],
        ],
      );
    }

    return FutureBuilder<List<NewsArticle>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return AsyncErrorView(
            error: snapshot.error!,
            onRetry: () => setState(() => _loadArticles(_category)),
          );
        }

        if (_articles.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('अहिले समाचार उपलब्ध छैन।'),
                  const SizedBox(height: 16),
                  _backButton(),
                ],
              ),
            ),
          );
        }

        // Voice flow is started from _loadArticles when the future completes.

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: _articles.length + 3,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _backButton();
            }
            if (index == 1) {
              return BigActionButton(
                icon: Icons.mic,
                title: 'समाचार नम्बर बोल्नुहोस्',
                subtitle: 'उदाहरण: १, २, ३… वा “पछाडि”',
                onPressed: voice.isListening ? null : _promptForNewsNumber,
              );
            }
            if (index == 2) {
              return OutlinedButton.icon(
                onPressed: () => setState(() => _categoryChosen = false),
                icon: const Icon(Icons.tune),
                label: Text(
                  _category == null
                      ? 'विषय छान्नुहोस्'
                      : 'विषय: ${categoryLabelNepali(_category!)} (परिवर्तन गर्नुहोस्)',
                ),
              );
            }
            final a = _articles[index - 3];
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
