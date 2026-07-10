class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.title,
    required this.source,
    required this.publishedAt,
    required this.summary,
    this.fullText,
  });

  final String id;
  final String title;
  final String source;
  final DateTime publishedAt;
  final String summary;
  final String? fullText;
}
